export type TimerBackend = {
  now: () => number;
  setInterval: (cb: () => void, ms: number) => any;
  clearInterval: (id: any) => void;
};

const defaultBackend: TimerBackend = {
  now: () => Date.now(),
  setInterval: (cb, ms) => setInterval(cb, ms),
  clearInterval: (id) => clearInterval(id),
};

type SessionTimerState = {
  running: boolean;
  elapsedSeconds: number;
};

type RestTimerState = {
  running: boolean;
  remainingSeconds: number;
  durationSeconds: number;
};

type Unsubscribe = () => void;

const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));

export const createSessionTimerController = (opts?: {
  backend?: TimerBackend;
  initialElapsedSeconds?: number;
  tickMs?: number;
}) => {
  const backend = opts?.backend ?? defaultBackend;
  const tickMs = opts?.tickMs ?? 1000;
  let elapsedSeconds = opts?.initialElapsedSeconds ?? 0;
  let running = false;
  let startEpochMs: number | null = null;
  let intervalId: any = null;
  const listeners = new Set<(state: SessionTimerState) => void>();

  const emit = () => {
    const state = { running, elapsedSeconds };
    listeners.forEach((listener) => listener(state));
  };

  const tick = () => {
    if (!running || startEpochMs === null) return;
    const nextElapsed = Math.max(0, Math.floor((backend.now() - startEpochMs) / 1000));
    if (nextElapsed !== elapsedSeconds) {
      elapsedSeconds = nextElapsed;
      emit();
    }
  };

  const start = () => {
    if (running) return;
    running = true;
    startEpochMs = backend.now() - elapsedSeconds * 1000;
    intervalId = backend.setInterval(tick, tickMs);
    emit();
  };

  const pause = () => {
    if (!running) return;
    tick();
    running = false;
    startEpochMs = null;
    if (intervalId !== null) {
      backend.clearInterval(intervalId);
      intervalId = null;
    }
    emit();
  };

  const reset = () => {
    running = false;
    elapsedSeconds = 0;
    startEpochMs = null;
    if (intervalId !== null) {
      backend.clearInterval(intervalId);
      intervalId = null;
    }
    emit();
  };

  const setElapsedSeconds = (seconds: number) => {
    const next = Math.max(0, Math.floor(seconds));
    elapsedSeconds = next;
    if (running) {
      startEpochMs = backend.now() - elapsedSeconds * 1000;
    }
    emit();
  };

  const setTime = (seconds: number) => setElapsedSeconds(seconds);

  const getState = (): SessionTimerState => ({ running, elapsedSeconds });

  const subscribe = (listener: (state: SessionTimerState) => void): Unsubscribe => {
    listeners.add(listener);
    listener(getState());
    return () => listeners.delete(listener);
  };

  return {
    start,
    pause,
    reset,
    setTime,
    setElapsedSeconds,
    getState,
    subscribe,
  };
};

export const createRestTimerController = (opts?: {
  backend?: TimerBackend;
  durationSeconds?: number;
  tickMs?: number;
  onFinished?: () => void;
}) => {
  const backend = opts?.backend ?? defaultBackend;
  const tickMs = opts?.tickMs ?? 1000;
  let durationSeconds = Math.max(1, Math.floor(opts?.durationSeconds ?? 120));
  let remainingSeconds = durationSeconds;
  let running = false;
  let startEpochMs: number | null = null;
  let intervalId: any = null;
  const listeners = new Set<(state: RestTimerState) => void>();
  const onFinished = opts?.onFinished ?? (() => {});

  const emit = () => {
    const state = { running, remainingSeconds, durationSeconds };
    listeners.forEach((listener) => listener(state));
  };

  const finish = () => {
    running = false;
    if (intervalId !== null) {
      backend.clearInterval(intervalId);
      intervalId = null;
    }
    startEpochMs = null;
    remainingSeconds = 0;
    emit();
    onFinished();
  };

  const tick = () => {
    if (!running || startEpochMs === null) return;
    const elapsed = Math.max(0, Math.floor((backend.now() - startEpochMs) / 1000));
    const nextRemaining = clamp(durationSeconds - elapsed, 0, durationSeconds);
    if (nextRemaining !== remainingSeconds) {
      remainingSeconds = nextRemaining;
      emit();
    }
    if (nextRemaining <= 0) {
      finish();
    }
  };

  const start = () => {
    if (running) return;
    running = true;
    startEpochMs = backend.now() - (durationSeconds - remainingSeconds) * 1000;
    intervalId = backend.setInterval(tick, tickMs);
    emit();
  };

  const pause = () => {
    if (!running) return;
    tick();
    running = false;
    startEpochMs = null;
    if (intervalId !== null) {
      backend.clearInterval(intervalId);
      intervalId = null;
    }
    emit();
  };

  const reset = () => {
    running = false;
    remainingSeconds = durationSeconds;
    startEpochMs = null;
    if (intervalId !== null) {
      backend.clearInterval(intervalId);
      intervalId = null;
    }
    emit();
  };

  const setRemainingSeconds = (seconds: number) => {
    const next = clamp(Math.floor(seconds), 0, durationSeconds);
    remainingSeconds = next;
    if (running) {
      startEpochMs = backend.now() - (durationSeconds - remainingSeconds) * 1000;
    }
    emit();
  };

  const setDurationSeconds = (seconds: number) => {
    const nextDuration = Math.max(1, Math.floor(seconds));
    durationSeconds = nextDuration;
    if (remainingSeconds > durationSeconds) {
      remainingSeconds = durationSeconds;
    }
    if (running) {
      startEpochMs = backend.now() - (durationSeconds - remainingSeconds) * 1000;
    }
    emit();
  };

  const setTime = (seconds: number) => setRemainingSeconds(seconds);

  const getState = (): RestTimerState => ({ running, remainingSeconds, durationSeconds });

  const subscribe = (listener: (state: RestTimerState) => void): Unsubscribe => {
    listeners.add(listener);
    listener(getState());
    return () => listeners.delete(listener);
  };

  return {
    start,
    pause,
    reset,
    setTime,
    setRemainingSeconds,
    setDurationSeconds,
    getState,
    subscribe,
  };
};
