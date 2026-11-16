import { type RefObject, useEffect, useLayoutEffect, useRef } from 'react';

import {
  DEAL_MS,
  DEAL_STAGGER_MS,
  DEAL_TOUCHDOWN,
  dealDirection,
  dealKeyframes,
  FADE_IN_KEYFRAMES,
  FADE_MS,
  feltArrivals,
  FLIP_KEYFRAMES,
  FLIP_MS,
  flippedCards,
  freshEvents,
  handArrivals,
  highestSeq,
  HOP_MS,
  hopKeyframes,
  isShuffled,
  movedCards,
  prefersReducedMotion,
  SLIDE_MS,
} from './motion';
import { CLICK_VOLUME, DEALT_VOLUME, LAND_SOUND, TURN_SOUND } from './sounds';
import type { FeltCard, GamingClothData } from './types';
import type { PlaySound } from './useSoundPool';
import { rotate } from './view';

/**
 * Plays what the table's new events did: cards thrown onto the felt or into
 * the hand, cards turned over, moves and shuffles, each with its sound. An
 * event plays once, when its seq is above the highest seen, and the first
 * payload only sets that mark. Each motion is handed to the browser as a
 * Web Animation on an element that already holds the card at its new place,
 * so a card never shows at its spot before it flies there and nothing is
 * left running once it lands.
 */
export function useEvents(
  rootRef: RefObject<HTMLDivElement | null>,
  data: GamingClothData,
  angle: number,
  play: PlaySound,
) {
  const mark = useRef<number | null>(null);
  const feltBefore = useRef(new Map<number, FeltCard>());
  const handBefore = useRef(new Set<number>());
  const timers = useRef(new Set<ReturnType<typeof setTimeout>>());

  const later = (delay: number, action: () => void) => {
    const timer = setTimeout(() => {
      timers.current.delete(timer);
      action();
    }, delay);
    timers.current.add(timer);
  };

  useLayoutEffect(() => {
    if (data.revision === undefined) {
      return;
    }
    const felt = data.felt || [];
    const hand = data.hand || [];
    const you = data.you || 0;
    const fresh = freshEvents(data.events, mark.current);
    const isFirst = mark.current === null;
    const before = feltBefore.current;
    const handWas = handBefore.current;
    mark.current = highestSeq(data.events, mark.current);
    feltBefore.current = new Map(felt.map((card) => [card.h, card]));
    handBefore.current = new Set(hand.map((card) => card.h));
    const root = rootRef.current;
    if (isFirst || !root) {
      return;
    }
    const isReduced = prefersReducedMotion();
    const find = (selector: string) =>
      root.querySelector<HTMLElement>(selector);

    feltArrivals(fresh, new Set(before.keys()), felt, you).forEach(
      (arrival, index) => {
        const element = find(`[data-motion="card-${arrival.h}"]`);
        if (!element) {
          return;
        }
        const delay = index * DEAL_STAGGER_MS;
        const { x, y } = arrival.offset;
        const direction = dealDirection(rotate(x, y, angle).x);
        const start = `translate(${x / 10}cqw, ${y / 10}cqw)`;
        element.animate(
          isReduced
            ? FADE_IN_KEYFRAMES
            : dealKeyframes(start, direction, angle),
          {
            duration: isReduced ? FADE_MS : DEAL_MS,
            delay,
            fill: 'backwards',
          },
        );
        later(delay + DEAL_MS * DEAL_TOUCHDOWN, () => play(LAND_SOUND));
      },
    );

    const arriving = handArrivals(fresh, handWas, hand, you);
    const fan = find('.GamingCloth__fan');
    const deck =
      find('.GamingCloth__layer .GamingCloth__deck') ??
      find('.GamingCloth__felt');
    // tgui may zoom the page, so screen pixels are brought back to the fan's own
    const zoom =
      fan && fan.offsetWidth
        ? fan.getBoundingClientRect().width / fan.offsetWidth
        : 1;
    arriving.forEach((arrival, index) => {
      const element = find(`[data-motion="hand-${arrival.h}"]`);
      if (!element) {
        return;
      }
      const delay = index * DEAL_STAGGER_MS;
      later(delay + DEAL_MS * DEAL_TOUCHDOWN, () =>
        play(LAND_SOUND, DEALT_VOLUME),
      );
      if (isReduced || !arrival.isDealt || !deck) {
        element.animate(FADE_IN_KEYFRAMES, {
          duration: FADE_MS,
          delay,
          fill: 'backwards',
        });
        return;
      }
      const from = deck.getBoundingClientRect();
      const spot = element.getBoundingClientRect();
      const lean = Number(element.dataset.lean) || 0;
      const screenX = (from.left + from.width / 2 - spot.left) / zoom;
      const screenY = (from.top + from.height / 2 - spot.top) / zoom;
      const local = rotate(screenX, screenY, -lean);
      const start = `translate(${local.x}px, ${local.y}px)`;
      element.animate(dealKeyframes(start, dealDirection(screenX), lean), {
        duration: DEAL_MS,
        delay,
        fill: 'backwards',
      });
    });

    for (const handle of flippedCards(fresh, before, felt)) {
      find(`.GamingCloth__layer [data-h="${handle}"]`)?.animate(
        isReduced ? FADE_IN_KEYFRAMES : FLIP_KEYFRAMES,
        { duration: FLIP_MS, easing: 'ease-out' },
      );
      play(TURN_SOUND, CLICK_VOLUME);
    }

    movedCards(fresh, before, felt).forEach(() =>
      later(SLIDE_MS, () => play(LAND_SOUND, CLICK_VOLUME)),
    );

    if (isShuffled(fresh) && !isReduced) {
      find('[data-motion="deck"]')?.animate(hopKeyframes(angle), {
        duration: HOP_MS,
      });
    }
  }, [data.revision, data.events, data.felt, data.hand]);

  // A hidden or unfocused window can freeze an animation partway, so everything lands at once
  useEffect(() => {
    const settle = () => {
      for (const timer of timers.current) {
        clearTimeout(timer);
      }
      timers.current.clear();
      for (const animation of rootRef.current?.getAnimations({
        subtree: true,
      }) ?? []) {
        if (animation.effect?.getTiming().iterations !== Infinity) {
          animation.finish();
        }
      }
    };
    window.addEventListener('blur', settle);
    window.addEventListener('focus', settle);
    document.addEventListener('visibilitychange', settle);
    return () => {
      window.removeEventListener('blur', settle);
      window.removeEventListener('focus', settle);
      document.removeEventListener('visibilitychange', settle);
      for (const timer of timers.current) {
        clearTimeout(timer);
      }
    };
  }, []);
}
