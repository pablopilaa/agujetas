import React, { useEffect, useMemo, useState } from 'react';
import { View, Text, StyleSheet, useColorScheme, LayoutChangeEvent } from 'react-native';
import { getExerciseHistoryIndex, type ExerciseHistory } from '../utils/storage';
import { getTheme } from '../utils/theme';

type ViewMode = 'daily' | 'weekly' | 'monthly';

interface Props {
  exerciseKey: string; // nombre normalizado del ejercicio
  view?: ViewMode;
}

interface Point {
  key: string;
  value: number;
  date: Date;
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

const sumSeries = (series: ExerciseHistory['series']): number => {
  return series.reduce((acc, s) => {
    const reps = parseNumber(s.reps);
    const kg = parseNumber(s.kg);
    return acc + reps * kg;
  }, 0);
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
  const day = (d.getDay() + 6) % 7; // lunes = 0
  d.setDate(d.getDate() - day);
  return toDateKey(d);
};

const aggregateHistory = (history: ExerciseHistory[], view: ViewMode): Point[] => {
  const totals = new Map<string, { value: number; date: Date }>();
  for (const ex of history) {
    const rawDate = ex.fecha || '';
    const date = rawDate ? new Date(rawDate) : new Date(0);
    const key = view === 'monthly' ? toMonthKey(date) : view === 'weekly' ? toWeekKey(date) : toDateKey(date);
    const total = sumSeries(ex.series || []);
    const existing = totals.get(key);
    if (existing) {
      existing.value += total;
    } else {
      totals.set(key, { value: total, date });
    }
  }
  return Array.from(totals.entries())
    .map(([key, v]) => ({ key, value: v.value, date: v.date }))
    .sort((a, b) => a.date.getTime() - b.date.getTime());
};

const ExerciseProgressChart: React.FC<Props> = ({ exerciseKey, view = 'daily' }) => {
  const colorScheme = useColorScheme();
  const theme = getTheme(colorScheme === 'dark');
  const [points, setPoints] = useState<Point[]>([]);
  const [layoutWidth, setLayoutWidth] = useState(0);

  useEffect(() => {
    let mounted = true;
    (async () => {
      const index = await getExerciseHistoryIndex();
      const key = normalizeExerciseName(exerciseKey);
      const history = index[key] || [];
      const aggregated = aggregateHistory(history, view);
      if (mounted) setPoints(aggregated);
    })();
    return () => { mounted = false; };
  }, [exerciseKey, view]);

  const chart = useMemo(() => {
    if (points.length === 0 || layoutWidth <= 0) return null;
    const width = layoutWidth;
    const height = 160;
    const padding = 16;
    const chartWidth = Math.max(0, width - padding * 2);
    const chartHeight = Math.max(0, height - padding * 2);
    const values = points.map(p => p.value);
    const min = Math.min(...values);
    const max = Math.max(...values);
    const range = max - min || 1;
    const step = points.length > 1 ? chartWidth / (points.length - 1) : 0;
    const mapped = points.map((p, i) => {
      const x = padding + (points.length > 1 ? i * step : chartWidth / 2);
      const y = padding + (1 - (p.value - min) / range) * chartHeight;
      return { x, y };
    });
    return { width, height, padding, chartWidth, chartHeight, mapped };
  }, [points, layoutWidth]);

  const onLayout = (e: LayoutChangeEvent) => {
    setLayoutWidth(e.nativeEvent.layout.width);
  };

  if (points.length === 0) {
    return <Text style={{ color: theme.textSecondary }}>No hay datos suficientes</Text>;
  }

  return (
    <View onLayout={onLayout} style={styles.container}>
      {!chart ? null : (
        <View style={[styles.chart, { height: chart.height }]}>
          <View style={[styles.axisY, { left: chart.padding, top: chart.padding, height: chart.chartHeight, backgroundColor: theme.border }]} />
          <View style={[styles.axisX, { left: chart.padding, top: chart.padding + chart.chartHeight, width: chart.chartWidth, backgroundColor: theme.border }]} />
          {chart.mapped.map((p, i) => {
            if (i === 0) return null;
            const prev = chart.mapped[i - 1];
            const dx = p.x - prev.x;
            const dy = p.y - prev.y;
            const length = Math.hypot(dx, dy);
            const angle = Math.atan2(dy, dx) * (180 / Math.PI);
            return (
              <View
                key={`line-${i}`}
                style={[
                  styles.line,
                  {
                    width: length,
                    backgroundColor: theme.primary,
                    left: prev.x,
                    top: prev.y,
                    transform: [{ rotateZ: `${angle}deg` }],
                  },
                ]}
              />
            );
          })}
          {chart.mapped.map((p, i) => (
            <View
              key={`dot-${i}`}
              style={[
                styles.dot,
                {
                  backgroundColor: theme.primary,
                  left: p.x - 2,
                  top: p.y - 2,
                },
              ]}
            />
          ))}
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
  },
  dot: {
    position: 'absolute',
    width: 4,
    height: 4,
    borderRadius: 2,
  },
});

export default ExerciseProgressChart;
