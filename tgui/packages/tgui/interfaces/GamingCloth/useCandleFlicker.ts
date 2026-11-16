import { type RefObject, useEffect, useRef } from 'react';

import { prefersReducedMotion } from './motion';

const CANDLE_HOLD_MS = 400;
const CANDLE_SETTLE_MS = 2500;

const STIRRING = 'GamingCloth__glow--stirring';

/**
 * Flickers the candle glow on the felt while the pointer moves anywhere in
 * the window, the gallery's flicker. A short rest pauses the flicker where
 * it is and the next move plays on from there, so a hand that moves in
 * bursts never restarts it. A long rest or leaving eases it back to steady,
 * and a move during that ease waits for it to finish, as the flicker starts
 * from full brightness. The stylesheet's animation plays the flicker, so
 * the script only writes a class and a play state and nothing per frame.
 * A constant flicker keeps the felt redrawing, so it never runs at rest.
 */
export function useCandleFlicker(rootRef: RefObject<HTMLDivElement | null>) {
  const glowRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const root = rootRef.current;
    const glow = glowRef.current;
    if (!root || !glow || prefersReducedMotion()) {
      return;
    }
    let holdTimer: ReturnType<typeof setTimeout> | null = null;
    let settleTimer: ReturnType<typeof setTimeout> | null = null;
    let settleFrame: number | null = null;
    let isFlickering = false;
    let isHeld = false;
    let isSettling = false;

    const clearTimers = () => {
      if (holdTimer !== null) {
        clearTimeout(holdTimer);
        holdTimer = null;
      }
      if (settleTimer !== null) {
        clearTimeout(settleTimer);
        settleTimer = null;
      }
    };

    const finishSettle = () => {
      if (settleFrame !== null) {
        cancelAnimationFrame(settleFrame);
        settleFrame = null;
      }
      isSettling = false;
      glow.style.opacity = '';
      glow.style.transition = '';
    };

    const settle = () => {
      clearTimers();
      if (!isFlickering) {
        return;
      }
      const level = window.getComputedStyle(glow).opacity;
      glow.classList.remove(STIRRING);
      glow.style.animationPlayState = '';
      isFlickering = false;
      isHeld = false;
      if (Number(level) >= 1) {
        return;
      }
      isSettling = true;
      glow.style.opacity = level;
      glow.style.transition = 'opacity 0.8s ease-in-out';
      // The style read makes the browser take the held level before the next frame clears it
      void window.getComputedStyle(glow).opacity;
      settleFrame = requestAnimationFrame(() => {
        settleFrame = null;
        glow.style.opacity = '';
      });
    };

    const hold = () => {
      holdTimer = null;
      isHeld = true;
      glow.style.animationPlayState = 'paused';
      settleTimer = setTimeout(settle, CANDLE_SETTLE_MS - CANDLE_HOLD_MS);
    };

    const stir = () => {
      if (isSettling || document.hidden) {
        return;
      }
      clearTimers();
      holdTimer = setTimeout(hold, CANDLE_HOLD_MS);
      if (isHeld) {
        isHeld = false;
        glow.style.animationPlayState = '';
        return;
      }
      if (!isFlickering) {
        isFlickering = true;
        glow.classList.add(STIRRING);
      }
    };

    // A cancelled ease ends the settle too, or a move would wait on it forever
    const handleTransitionDone = (event: TransitionEvent) => {
      if (
        event.propertyName !== 'opacity' ||
        !isSettling ||
        settleFrame !== null
      ) {
        return;
      }
      finishSettle();
    };

    const handleVisibilityChange = () => {
      if (document.hidden) {
        settle();
      }
    };

    root.addEventListener('mousemove', stir);
    root.addEventListener('mouseleave', settle);
    glow.addEventListener('transitionend', handleTransitionDone);
    glow.addEventListener('transitioncancel', handleTransitionDone);
    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => {
      root.removeEventListener('mousemove', stir);
      root.removeEventListener('mouseleave', settle);
      glow.removeEventListener('transitionend', handleTransitionDone);
      glow.removeEventListener('transitioncancel', handleTransitionDone);
      document.removeEventListener('visibilitychange', handleVisibilityChange);
      clearTimers();
      finishSettle();
      glow.classList.remove(STIRRING);
      glow.style.animationPlayState = '';
    };
  }, []);

  return glowRef;
}
