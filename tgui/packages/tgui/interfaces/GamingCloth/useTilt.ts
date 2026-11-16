import { useEffect, useRef } from 'react';

import {
  aimTilt,
  prefersReducedMotion,
  TILT_REST_MS,
  tiltRotate,
} from './motion';
import type { Point } from './types';

/**
 * Leans a lifted card toward the pointer while the pointer is over it, the
 * gallery's tilt. The script only picks targets and writes one rotate
 * value, and the stylesheet's transition plays the ease, so nothing runs per
 * frame. The card lies flat again when the pointer leaves or the card is
 * set down.
 */
export function useTilt(enabled: boolean, rot: number) {
  const faceRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const face = faceRef.current;
    if (!enabled || !face || prefersReducedMotion()) {
      return;
    }
    let pointer: Point | null = null;
    let restTimer: ReturnType<typeof setTimeout> | null = null;
    let target: Point = { x: 0, y: 0 };
    // An unchanged target writes nothing, so the running transition is left alone
    let written = '';

    const apply = (exact: boolean) => {
      target = aimTilt(
        pointer,
        face.getBoundingClientRect(),
        rot,
        target,
        exact,
      );
      const next = tiltRotate(target);
      if (next !== written) {
        written = next;
        face.style.rotate = next;
      }
    };

    const clearRest = () => {
      if (restTimer !== null) {
        clearTimeout(restTimer);
        restTimer = null;
      }
    };

    const handleMove = (event: MouseEvent) => {
      pointer = { x: event.clientX, y: event.clientY };
      clearRest();
      // The dead zone can stop the lean short of where the pointer is,
      // so once it rests one more aim goes there exactly
      restTimer = setTimeout(() => {
        restTimer = null;
        apply(true);
      }, TILT_REST_MS);
      apply(false);
    };

    const handleLeave = () => {
      pointer = null;
      clearRest();
      apply(false);
    };

    face.addEventListener('mousemove', handleMove);
    face.addEventListener('mouseleave', handleLeave);
    return () => {
      face.removeEventListener('mousemove', handleMove);
      face.removeEventListener('mouseleave', handleLeave);
      clearRest();
      face.style.rotate = '';
    };
  }, [enabled, rot]);

  return faceRef;
}
