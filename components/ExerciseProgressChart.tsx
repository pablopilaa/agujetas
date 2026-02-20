import React, { useEffect, useMemo, useState } from 'react';
import { View, Text, StyleSheet, useColorScheme, LayoutChangeEvent, ScrollView, TouchableOpacity } from 'react-native';
import { getExerciseHistoryIndex, type ExerciseHistory } from '../utils/storage';
import { getTheme } from '../utils/theme';

type ViewMode = 'daily' | 'weekly' | 'monthly';
type RenderMode = 'chart' | 'history';

interface Props {
  exerciseKey: string; // normalized exercise name
  view?: ViewMode;
  startDateISO?: string;
  endDateISO?: string;
  mode?: RenderMode;
  isDarkMode?: boolean;
  lineColor?: string;
  lineStrokeColor?: string;
  axisColor?: string;
}

interface Point {
  key: string;
  value: number;
  date: Date;
  reps: string;
  rir?: number;
}

interface Tick {
  label: string;
  y: number;
}

const normalizeExerciseName = (name: string): string => {
  return name
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, ' ');
};

const parseNumber = (value: string | number | undefined): number => {
  if (value === undefined || value === null) return 0;
  if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
  const cleaned = value.replace(',', '.').trim();
  const parsed = parseFloat(cleaned);
  return Number.isFinite(parsed) ? parsed : 0;
};

const parseRir = (value: unknown): number | undefined => {
  if (value === undefined || value === null || value === '') return undefined;
  if (typeof value === 'number') return Number.isFinite(value) ? value : undefined;
  const parsed = parseFloat(String(value).replace(',', '.').trim());
  return Number.isFinite(parsed) ? parsed : undefined;
};

const getMaxSeries = (series: ExerciseHistory['series']): { kg: number; reps: string; rir?: number } | null => {
  let best: { kg: number; reps: string; rir?: number } | null = null;
  for (const s of series || []) {
    const kg = parseNumber(s.kg);
    if (!Number.isFinite(kg)) continue;
    const reps = String(s.reps || '').trim();
    const rir = parseRir((s as any).rir);
    const shouldReplace =
      !best ||
      kg > best.kg ||
      (kg === best.kg && best.rir === undefined && rir !== undefined);
    if (shouldReplace) {
      best = { kg, reps, rir };
    }
  }
  return best;
};

const toDateKey = (date: Date): string => {
  const yyyy = date.getFullYear();
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  const dd = String(date.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
};

const toMonthKey = (date: Date): string => {
  const yyyy = date.getFullYear();
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  return `${yyyy}-${mm}`;
};

const toWeekKey = (date: Date): string => {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  const day = (d.getDay() + 6) % 7; // monday = 0
  d.setDate(d.getDate() - day);
  return toDateKey(d);
};

const parseISODate = (value?: string): Date | null => {
  if (!value) return null;
  const raw = value.trim();
  if (!raw) return null;
  const date = /^\d{4}-\d{2}-\d{2}$/.test(raw) ? new Date(`${raw}T00:00:00`) : new Date(raw);
  return Number.isNaN(date.getTime()) ? null : date;
};

const formatTickValue = (value: number): string => {
  if (!Number.isFinite(value)) return '0';
  if (value >= 1000) return `${Math.round(value).toLocaleString('es-ES')}`;
  return `${Math.round(value)}`;
};

const formatXAxisLabel = (date: Date, view: ViewMode): string => {
  if (view === 'monthly') {
    return date.toLocaleDateString('es-ES', { month: 'short', year: '2-digit' });
  }
  return date.toLocaleDateString('es-ES', { day: '2-digit', month: '2-digit' });
};

const filterHistoryByRange = (history: ExerciseHistory[], startDateISO?: string, endDateISO?: string): ExerciseHistory[] => {
  const start = parseISODate(startDateISO);
  const end = parseISODate(endDateISO);
  if (!start && !end) return history;

  return history.filter((item) => {
    const date = parseISODate(item.fecha);
    if (!date) return false;
    if (start && date.getTime() < start.getTime()) return false;
    if (end && date.getTime() > end.getTime()) return false;
    return true;
  });
};

const aggregateHistory = (history: ExerciseHistory[], view: ViewMode): Point[] => {
  const bestByPeriod = new Map<string, Point>();
  for (const ex of history) {
    const date = parseISODate(ex.fecha);
    if (!date) continue;
    const bestSeries = getMaxSeries(ex.series || []);
    if (!bestSeries) continue;
    const key = view === 'monthly' ? toMonthKey(date) : view === 'weekly' ? toWeekKey(date) : toDateKey(date);
    const existing = bestByPeriod.get(key);
    if (!existing || bestSeries.kg > existing.value) {
      const periodDate =
        view === 'monthly'
          ? new Date(date.getFullYear(), date.getMonth(), 1)
          : view === 'weekly'
          ? parseISODate(toWeekKey(date)) || date
          : date;
      bestByPeriod.set(key, {
        key,
        value: bestSeries.kg,
        date: periodDate,
        reps: bestSeries.reps,
        rir: bestSeries.rir,
      });
    }
  }
  return Array.from(bestByPeriod.values()).sort((a, b) => a.date.getTime() - b.date.getTime());
};

const ExerciseProgressChart: React.FC<Props> = ({
  exerciseKey,
  view = 'daily',
  startDateISO,
  endDateISO,
  mode = 'chart',
  isDarkMode,
  lineColor,
  lineStrokeColor,
  axisColor,
}) => {
  const colorScheme = useColorScheme();
  const theme = getTheme(isDarkMode ?? (colorScheme === 'dark'));
  const [filteredHistory, setFilteredHistory] = useState<ExerciseHistory[]>([]);
  const [points, setPoints] = useState<Point[]>([]);
  const [layoutWidth, setLayoutWidth] = useState(0);
  const [selectedPointIndex, setSelectedPointIndex] = useState<number | null>(null);
  const [historyContentHeight, setHistoryContentHeight] = useState(1);
  const [historyScrollY, setHistoryScrollY] = useState(0);
  const HISTORY_VIEWPORT_HEIGHT = 260;

  const historySeriesByDate = useMemo(() => {
    const grouped = new Map<string, Array<{ seriesNumber: number; kg: number; reps: string; rir?: number }>>();
    for (const item of filteredHistory) {
      const dateKey = (item.fecha || '').slice(0, 10) || '-';
      const rows = grouped.get(dateKey) || [];
      (item.series || []).forEach((s, idx) => {
        rows.push({
          seriesNumber: idx + 1,
          kg: parseNumber(s.kg),
          reps: String(s.reps || '').trim(),
          rir: parseRir((s as any).rir),
        });
      });
      grouped.set(dateKey, rows);
    }
    return Array.from(grouped.entries()).sort((a, b) => new Date(a[0]).getTime() - new Date(b[0]).getTime());
  }, [filteredHistory]);

  useEffect(() => {
    let mounted = true;
    (async () => {
      const index = await getExerciseHistoryIndex();
      const key = normalizeExerciseName(exerciseKey);
      const history = index[key] || [];
      const nextFiltered = filterHistoryByRange(history, startDateISO, endDateISO);
      const aggregated = aggregateHistory(nextFiltered, view);
      if (mounted) {
        setFilteredHistory(nextFiltered);
        setPoints(aggregated);
        setSelectedPointIndex(null);
      }
    })();
    return () => {
      mounted = false;
    };
  }, [exerciseKey, view, startDateISO, endDateISO]);

  const chart = useMemo(() => {
    if (layoutWidth <= 0) return null;
    const width = layoutWidth;
    const height = 214;
    const leftPadding = 44;
    const rightPadding = 14;
    const topPadding = 14;
    const bottomPadding = 32;
    const chartWidth = Math.max(0, width - leftPadding - rightPadding);
    const chartHeight = Math.max(0, height - topPadding - bottomPadding);
    const hasData = points.length > 0;
    const values = hasData ? points.map((p) => p.value) : [0];
    const min = Math.min(...values);
    const max = Math.max(...values);
    const rawRange = max - min;
    const dynamicPadding = hasData
      ? (rawRange > 0 ? rawRange * 0.12 : Math.max(5, max * 0.12 || 1))
      : 1;
    const yMin = hasData ? Math.max(0, min - dynamicPadding) : 0;
    const yMax = hasData ? max + dynamicPadding : 2;
    const range = yMax - yMin || 1;
    const step = points.length > 1 ? chartWidth / (points.length - 1) : 0;
    const mapped = points.map((p, i) => {
      const x = leftPadding + (points.length > 1 ? i * step : chartWidth / 2);
      const y = topPadding + (1 - (p.value - yMin) / range) * chartHeight;
      return { x, y };
    });
    const tickValues = [yMax, yMin + range / 2, yMin];
    const ticks: Tick[] = tickValues.map((value) => ({
      label: formatTickValue(value),
      y: topPadding + (1 - (value - yMin) / range) * chartHeight,
    }));
    return {
      hasData,
      width,
      height,
      leftPadding,
      rightPadding,
      topPadding,
      bottomPadding,
      chartWidth,
      chartHeight,
      mapped,
      ticks,
      xStart: leftPadding,
      xEnd: leftPadding + chartWidth,
      yBottom: topPadding + chartHeight,
    };
  }, [points, layoutWidth]);

  const onLayout = (e: LayoutChangeEvent) => {
    setLayoutWidth(e.nativeEvent.layout.width);
  };

  if (mode === 'history') {
    if (historySeriesByDate.length === 0) {
      return <Text style={{ color: theme.textSecondary }}>No hay datos suficientes</Text>;
    }
    const maxScroll = Math.max(1, historyContentHeight - HISTORY_VIEWPORT_HEIGHT);
    const thumbHeight =
      historyContentHeight <= HISTORY_VIEWPORT_HEIGHT
        ? HISTORY_VIEWPORT_HEIGHT
        : Math.max(28, (HISTORY_VIEWPORT_HEIGHT / historyContentHeight) * HISTORY_VIEWPORT_HEIGHT);
    const thumbTop =
      historyContentHeight <= HISTORY_VIEWPORT_HEIGHT
        ? 0
        : (Math.min(historyScrollY, maxScroll) / maxScroll) * (HISTORY_VIEWPORT_HEIGHT - thumbHeight);
    return (
      <View style={styles.historyViewport}>
        <View style={styles.historyScrollRow}>
          <ScrollView
            style={styles.historyList}
            contentContainerStyle={styles.historyListContent}
            nestedScrollEnabled={false}
            showsVerticalScrollIndicator={false}
            persistentScrollbar
            keyboardShouldPersistTaps="handled"
            scrollEnabled
            scrollEventThrottle={16}
            onContentSizeChange={(_, h) => setHistoryContentHeight(Math.max(1, h))}
            onScroll={(e) => setHistoryScrollY(e.nativeEvent.contentOffset.y)}
            overScrollMode="always"
          >
            {historySeriesByDate.map(([dateKey, seriesRows], idx) => {
              return (
                <View key={`${dateKey}-${idx}`} style={[styles.historyDayBlock, { borderBottomColor: theme.border }]}>
                  <Text style={[styles.historyDate, { color: theme.textSecondary }]}>{dateKey}</Text>
                  {seriesRows.length === 0 ? (
                    <Text style={[styles.historyContext, { color: theme.textSecondary }]}>Sin series registradas</Text>
                  ) : (
                    seriesRows.map((row, rowIdx) => (
                      <Text key={`${dateKey}-s-${rowIdx}`} style={[styles.historySeriesLine, { color: theme.textPrimary }]}>
                        Serie {row.seriesNumber}: {Math.round(row.kg)} kg • Reps {row.reps || '-'} / RIR {row.rir ?? '-'}
                      </Text>
                    ))
                  )}
                </View>
              );
            })}
          </ScrollView>
          <View pointerEvents="none" style={[styles.historyScrollbarTrack, { backgroundColor: axisColor || theme.border }]}>
            <View
              style={[
                styles.historyScrollbarThumb,
                {
                  height: thumbHeight,
                  transform: [{ translateY: thumbTop }],
                  backgroundColor: lineColor || theme.primary,
                },
              ]}
            />
          </View>
        </View>
      </View>
    );
  }

  return (
    <View onLayout={onLayout} style={styles.container}>
      {!chart ? null : (
        <View style={[styles.chart, { height: chart.height }]}>
          {chart.ticks.map((tick, index) => (
            <View key={`grid-${index}`}>
              <View
                style={[
                  styles.gridLine,
                  {
                    left: chart.xStart,
                    top: tick.y,
                    width: chart.chartWidth,
                    backgroundColor: axisColor || theme.border,
                  },
                ]}
              />
              <Text
                style={[
                  styles.tickLabel,
                  { color: theme.textSecondary, top: tick.y - 8 },
                ]}
              >
                {tick.label}
              </Text>
            </View>
          ))}
          <View
            style={[
              styles.axisY,
              {
                left: chart.xStart,
                top: chart.topPadding,
                height: chart.chartHeight,
                backgroundColor: axisColor || theme.border,
              },
            ]}
          />
          <View
            style={[
              styles.axisX,
              {
                left: chart.xStart,
                top: chart.yBottom,
                width: chart.chartWidth,
                backgroundColor: axisColor || theme.border,
              },
            ]}
          />
          {chart.hasData && chart.mapped.map((p, i) => {
            if (i === 0) return null;
            const prev = chart.mapped[i - 1];
            const dx = p.x - prev.x;
            const dy = p.y - prev.y;
            const length = Math.hypot(dx, dy);
            const angle = Math.atan2(dy, dx) * (180 / Math.PI);
            const midX = (prev.x + p.x) / 2;
            const midY = (prev.y + p.y) / 2;
            return (
              <View
                key={`line-${i}`}
              style={[
                styles.line,
                {
                  width: length,
                  backgroundColor: lineStrokeColor || lineColor || theme.primary,
                  // Position segment by midpoint so center-rotation aligns with both points.
                  left: midX - length / 2,
                  top: midY - 1,
                    transform: [{ rotateZ: `${angle}deg` }],
                  },
                ]}
              />
            );
          })}
          {chart.hasData && chart.mapped.map((p, i) => (
            <TouchableOpacity
              key={`dot-${i}`}
              activeOpacity={0.8}
              onPress={() => setSelectedPointIndex((prev) => (prev === i ? null : i))}
              style={[
                styles.dotHitbox,
                {
                  left: p.x - 10,
                  top: p.y - 10,
                },
              ]}
            >
              <View
                style={[
                  styles.dot,
                  {
                    backgroundColor: lineColor || theme.primary,
                  },
                ]}
              />
            </TouchableOpacity>
          ))}
          {chart.hasData && chart.mapped.map((p, i) => {
            const label = formatTickValue(points[i].value);
            const labelWidth = Math.max(24, label.length * 7);
            const left = Math.max(
              chart.xStart,
              Math.min(p.x - labelWidth / 2, chart.xEnd - labelWidth)
            );
            const top = Math.max(chart.topPadding - 2, p.y - 22);
            return (
              <Text
                key={`value-${i}`}
                style={[
                  styles.pointValueLabel,
                  {
                    left,
                    top,
                    width: labelWidth,
                    color: lineColor || theme.primary,
                  },
                ]}
              >
                {label}
              </Text>
            );
          })}
          {chart.hasData && selectedPointIndex !== null ? (
            <TouchableOpacity
              activeOpacity={1}
              onPress={() => setSelectedPointIndex(null)}
              style={[
                styles.chartTapDismissLayer,
                {
                  left: chart.xStart,
                  top: chart.topPadding,
                  width: chart.chartWidth,
                  height: chart.chartHeight,
                },
              ]}
            />
          ) : null}
          {chart.hasData && selectedPointIndex !== null && chart.mapped[selectedPointIndex] ? (() => {
            const point = points[selectedPointIndex];
            const mappedPoint = chart.mapped[selectedPointIndex];
            const tooltipWidth = 144;
            const left = Math.max(
              chart.xStart,
              Math.min(mappedPoint.x - tooltipWidth / 2, chart.xEnd - tooltipWidth)
            );
            const proposedTop = mappedPoint.y - 54;
            const top = proposedTop < chart.topPadding ? mappedPoint.y + 10 : proposedTop;
            return (
              <TouchableOpacity
                activeOpacity={0.9}
                onPress={() => setSelectedPointIndex(null)}
                style={[
                  styles.tooltip,
                  {
                    left,
                    top,
                    width: tooltipWidth,
                    backgroundColor: theme.surface,
                    borderColor: axisColor || theme.border,
                  },
                ]}
              >
                <Text style={[styles.tooltipValue, { color: lineColor || theme.primary }]}>
                  {formatTickValue(point.value)}
                </Text>
                <Text style={[styles.tooltipContext, { color: theme.textPrimary }]}>
                  Reps {point.reps || '-'} / RIR {point.rir ?? '-'}
                </Text>
              </TouchableOpacity>
            );
          })() : null}
          <Text style={[styles.xAxisLabel, { color: theme.textSecondary, left: chart.xStart - 4 }]}>
            {chart.hasData ? formatXAxisLabel(points[0].date, view) : '-'}
          </Text>
          <Text style={[styles.xAxisLabel, styles.xAxisLabelRight, { color: theme.textSecondary, right: chart.rightPadding }]}>
            {chart.hasData ? formatXAxisLabel(points[points.length - 1].date, view) : '-'}
          </Text>
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    width: '100%',
  },
  chart: {
    position: 'relative',
    width: '100%',
  },
  axisX: {
    position: 'absolute',
    height: 1,
  },
  axisY: {
    position: 'absolute',
    width: 1,
  },
  line: {
    position: 'absolute',
    height: 2,
    borderRadius: 2,
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: 3,
  },
  dotHitbox: {
    position: 'absolute',
    width: 20,
    height: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  pointValueLabel: {
    position: 'absolute',
    fontSize: 10,
    fontWeight: '700',
    textAlign: 'center',
    fontFamily: 'System',
  },
  gridLine: {
    position: 'absolute',
    height: 1,
    opacity: 0.3,
  },
  tickLabel: {
    position: 'absolute',
    left: 0,
    fontSize: 10,
    fontFamily: 'System',
  },
  xAxisLabel: {
    position: 'absolute',
    bottom: 8,
    fontSize: 10,
    fontFamily: 'System',
  },
  xAxisLabelRight: {
    textAlign: 'right',
  },
  chartTapDismissLayer: {
    position: 'absolute',
    zIndex: 20,
  },
  historyViewport: {
    width: '100%',
    height: 260,
  },
  historyScrollRow: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'stretch',
    position: 'relative',
  },
  historyList: {
    flex: 1,
    width: '100%',
  },
  historyListContent: {
    paddingBottom: 8,
    paddingRight: 12,
  },
  historyRow: {
    paddingVertical: 8,
    borderBottomWidth: 1,
  },
  historyDayBlock: {
    paddingVertical: 8,
    borderBottomWidth: 1,
  },
  historyDate: {
    fontSize: 12,
    marginBottom: 2,
    fontFamily: 'System',
  },
  historyValue: {
    fontSize: 14,
    fontWeight: '600',
    fontFamily: 'System',
  },
  historyContext: {
    fontSize: 12,
    marginTop: 2,
    fontFamily: 'System',
  },
  historySeriesLine: {
    fontSize: 12,
    marginTop: 3,
    fontFamily: 'System',
  },
  historyScrollbarTrack: {
    position: 'absolute',
    right: 0,
    top: 0,
    bottom: 0,
    width: 6,
    borderRadius: 999,
    opacity: 0.8,
    overflow: 'hidden',
  },
  historyScrollbarThumb: {
    width: '100%',
    borderRadius: 999,
  },
  tooltip: {
    position: 'absolute',
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: 8,
    paddingVertical: 6,
    zIndex: 30,
  },
  tooltipValue: {
    fontSize: 14,
    fontWeight: '700',
    fontFamily: 'System',
  },
  tooltipContext: {
    fontSize: 11,
    marginTop: 2,
    fontFamily: 'System',
  },
});

export default ExerciseProgressChart;
