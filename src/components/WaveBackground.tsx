import { useEffect, useRef, memo } from 'react';

const PALETTE = [
  { r: 160, g: 210, b: 240 }, // pale azure
  { r: 140, g: 190, b: 230 }, // soft sky
  { r: 120, g: 170, b: 220 }, // muted blue
];

function createWaveGradient(
  ctx: CanvasRenderingContext2D,
  height: number,
  layer: number,
  color: { r: number; g: number; b: number }
) {
  const yBase = height * (0.55 + layer * 0.1);
  const amplitude = height * (0.04 + layer * 0.015);
  const gradient = ctx.createLinearGradient(0, yBase - amplitude, 0, height);
  gradient.addColorStop(0, `rgba(${color.r}, ${color.g}, ${color.b}, ${0.12 - layer * 0.025})`);
  gradient.addColorStop(1, `rgba(${color.r}, ${color.g}, ${color.b}, 0)`);
  return gradient;
}

function drawWave(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
  time: number,
  layer: number,
  gradient: CanvasGradient
) {
  const yBase = height * (0.55 + layer * 0.1);
  const amplitude = height * (0.04 + layer * 0.015);
  const frequency = 0.002 + layer * 0.0006;
  const speed = 0.0005 + layer * 0.0002;
  const phase = time * speed + layer * 1.5;

  ctx.beginPath();
  ctx.moveTo(0, height);

  for (let x = 0; x <= width; x += 6) {
    const y =
      yBase +
      Math.sin(x * frequency + phase) * amplitude +
      Math.sin(x * frequency * 2 + phase * 1.2) * amplitude * 0.3;
    ctx.lineTo(x, y);
  }

  ctx.lineTo(width, height);
  ctx.closePath();

  ctx.fillStyle = gradient;
  ctx.fill();
}

function drawStaticBackground(ctx: CanvasRenderingContext2D, width: number, height: number) {
  const bgGradient = ctx.createLinearGradient(0, 0, 0, height);
  bgGradient.addColorStop(0, '#0f172a');
  bgGradient.addColorStop(0.5, '#1e2d42');
  bgGradient.addColorStop(1, '#243954');
  ctx.fillStyle = bgGradient;
  ctx.fillRect(0, 0, width, height);

  // Draw static waves at time 0 for reduced-motion preference.
  for (let i = 0; i < PALETTE.length; i++) {
    const gradient = createWaveGradient(ctx, height, i, PALETTE[i]);
    drawWave(ctx, width, height, 0, i, gradient);
  }
}

function WaveBackground() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const rafRef = useRef<number>(0);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const reducedMotion =
      typeof window !== 'undefined' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    const resize = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      canvas.width = window.innerWidth * dpr;
      canvas.height = window.innerHeight * dpr;
      canvas.style.width = `${window.innerWidth}px`;
      canvas.style.height = `${window.innerHeight}px`;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      if (reducedMotion) {
        drawStaticBackground(ctx, window.innerWidth, window.innerHeight);
      }
    };

    resize();
    window.addEventListener('resize', resize);

    let isVisible = true;
    const handleVisibility = () => {
      isVisible = document.visibilityState === 'visible';
      if (!reducedMotion && isVisible && !rafRef.current) {
        rafRef.current = requestAnimationFrame(animate);
      }
    };
    document.addEventListener('visibilitychange', handleVisibility);

    if (reducedMotion) {
      drawStaticBackground(ctx, window.innerWidth, window.innerHeight);
      return () => {
        window.removeEventListener('resize', resize);
        document.removeEventListener('visibilitychange', handleVisibility);
      };
    }

    const startTime = performance.now();
    let bgGradient: CanvasGradient | null = null;
    let waveGradients: CanvasGradient[] = [];
    let cachedHeight = 0;

    const animate = (now: number) => {
      if (!isVisible) {
        rafRef.current = 0;
        return;
      }
      const time = now - startTime;
      const width = window.innerWidth;
      const height = window.innerHeight;

      if (height !== cachedHeight) {
        cachedHeight = height;
        bgGradient = ctx.createLinearGradient(0, 0, 0, height);
        bgGradient.addColorStop(0, '#0f172a');
        bgGradient.addColorStop(0.5, '#1e2d42');
        bgGradient.addColorStop(1, '#243954');
        waveGradients = PALETTE.map((color, i) => createWaveGradient(ctx, height, i, color));
      }

      ctx.clearRect(0, 0, width, height);

      if (bgGradient) {
        ctx.fillStyle = bgGradient;
        ctx.fillRect(0, 0, width, height);
      }

      for (let i = 0; i < PALETTE.length; i++) {
        drawWave(ctx, width, height, time, i, waveGradients[i]);
      }

      rafRef.current = requestAnimationFrame(animate);
    };

    rafRef.current = requestAnimationFrame(animate);

    return () => {
      window.removeEventListener('resize', resize);
      document.removeEventListener('visibilitychange', handleVisibility);
      cancelAnimationFrame(rafRef.current);
      rafRef.current = 0;
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100%',
        height: '100%',
        zIndex: 0,
        pointerEvents: 'none',
      }}
    />
  );
}

export default memo(WaveBackground);
