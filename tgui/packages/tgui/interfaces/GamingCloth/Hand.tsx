import {
  type MouseEvent,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
} from 'react';
import { Button } from 'tgui-core/components';
import { classes } from 'tgui-core/react';

import { SortMode } from './cards';
import {
  type FanSpot,
  HAND_LIFT_RISE,
  handLayout,
  LIFT_SCALE,
} from './geometry';
import { PlayingCard } from './PlayingCard';
import type { HandCard } from './types';
import { useFaceMotion } from './useFaceMotion';
import { useTilt } from './useTilt';

type Props = {
  // Already in the order Sort chose
  hand: HandCard[];
  deckStyle: string;
  isSeated: boolean;
  selected: number | null;
  sortMode: SortMode;
  isFaceDown: boolean;
  onSelectCard: (handle: number) => void;
  onClearSelection: () => void;
};

/** A hand card's width in pixels, the height follows from the card's shape */
const HAND_CARD_WIDTH = 62;

const SORT_LABELS: Record<SortMode, string> = {
  [SortMode.Dealt]: 'As dealt',
  [SortMode.Suit]: 'By suit',
  [SortMode.Rank]: 'By rank',
};

type HeldCard = {
  card: HandCard;
  spot: FanSpot;
  depth: number;
};

type LeavingCard = HeldCard & { id: number };

/** The tray's width in pixels, read again only when the tray is resized */
function useTrayWidth() {
  const ref = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(0);
  useEffect(() => {
    const tray = ref.current;
    if (!tray) {
      return;
    }
    const observer = new ResizeObserver((entries) =>
      setWidth(entries[0].contentRect.width),
    );
    observer.observe(tray);
    return () => observer.disconnect();
  }, []);
  return [ref, width] as const;
}

/**
 * Cards that have just left the hand, kept where they were held while they
 * fade out. Each is dropped when its fade ends, so none is kept at rest.
 */
function useLeavingCards(held: HeldCard[]) {
  const [leaving, setLeaving] = useState<LeavingCard[]>([]);
  const shown = useRef<HeldCard[]>([]);
  const nextId = useRef(1);

  // Before paint, so a card that left never vanishes for a frame before its fade
  useLayoutEffect(() => {
    const now = new Set(held.map((entry) => entry.card.h));
    const gone = shown.current.filter((entry) => !now.has(entry.card.h));
    shown.current = held;
    if (!gone.length) {
      return;
    }
    setLeaving((list) => [
      ...list,
      ...gone.map((entry) => ({ ...entry, id: nextId.current++ })),
    ]);
  });

  const drop = (id: number) =>
    setLeaving((list) => list.filter((entry) => entry.id !== id));
  return [leaving, drop] as const;
}

const spotTransform = (spot: FanSpot) =>
  `translate(${spot.x}px, ${spot.y}px) rotate(${spot.angle}deg)`;

/** The viewer's own hand, fanned along the bottom of the window */
export function Hand(props: Props) {
  const {
    hand,
    deckStyle,
    isSeated,
    selected,
    sortMode,
    isFaceDown,
    onSelectCard,
    onClearSelection,
  } = props;
  const [trayRef, trayWidth] = useTrayWidth();
  // Before the first measure the fan only tightens by count
  const spots = handLayout(hand.length, trayWidth || Infinity, HAND_CARD_WIDTH);
  const held = hand.map((card, index) => ({
    card,
    spot: spots[index],
    depth: index + 1,
  }));
  const [leaving, dropLeaving] = useLeavingCards(held);

  const handleTrayClick = () => onClearSelection();

  return (
    <div className="GamingCloth__hand">
      <div className="GamingCloth__fan" ref={trayRef} onClick={handleTrayClick}>
        {!isSeated && (
          <div className="GamingCloth__handNote">Take a seat to hold cards</div>
        )}
        {held.map((entry) => (
          <HandCardView
            key={entry.card.h}
            held={entry}
            count={hand.length}
            deckStyle={deckStyle}
            isSelected={entry.card.h === selected}
            onSelect={onSelectCard}
          />
        ))}
        {leaving.map((entry) => {
          const handleFadeEnd = () => dropLeaving(entry.id);
          return (
            <div
              key={`gone-${entry.id}`}
              className="GamingCloth__fanSpot"
              style={{
                transform: spotTransform(entry.spot),
                zIndex: entry.depth,
              }}
            >
              <div
                className="GamingCloth__leaving"
                onAnimationEnd={handleFadeEnd}
              >
                <PlayingCard
                  name={entry.card.name}
                  deckStyle={deckStyle}
                  size="hand"
                />
              </div>
            </div>
          );
        })}
      </div>
      {isSeated && (
        <div className="GamingCloth__handButtons">
          <Button icon="sort">{SORT_LABELS[sortMode]}</Button>
          <Button.Checkbox checked={isFaceDown}>Face down</Button.Checkbox>
        </div>
      )}
    </div>
  );
}

type CardProps = {
  held: HeldCard;
  count: number;
  deckStyle: string;
  isSelected: boolean;
  onSelect: (handle: number) => void;
};

/**
 * One card in the fan. It leaps and wiggles while the pointer is over it,
 * hops as it is lifted out of the fan and leans toward the pointer while
 * up. The lift wrapper takes the hover and the click over the card's
 * resting box, so a leaping card never slides out from under the pointer
 * and drops again.
 */
function HandCardView(props: CardProps) {
  const { held, count, deckStyle, isSelected, onSelect } = props;
  const { card, spot, depth } = held;
  const { motion, handleEnter, handleLeave, handleAnimationEnd } =
    useFaceMotion(isSelected);
  const tiltRef = useTilt(isSelected, 0);

  const handleClick = (event: MouseEvent<HTMLDivElement>) => {
    event.stopPropagation();
    onSelect(card.h);
  };

  let shownDepth = depth;
  if (isSelected) {
    shownDepth = count + 2;
  } else if (motion === 'leap') {
    shownDepth = count + 1;
  }

  return (
    <div
      className="GamingCloth__fanSpot"
      style={{ transform: spotTransform(spot), zIndex: shownDepth }}
    >
      <div
        className="GamingCloth__arrival"
        data-motion={`hand-${card.h}`}
        data-lean={spot.angle}
      >
        <div
          className={classes([
            'GamingCloth__lift',
            isSelected && 'GamingCloth__lift--up',
          ])}
          style={
            isSelected
              ? {
                  transform: `translateY(${-HAND_LIFT_RISE * HAND_CARD_WIDTH}px) rotate(${-spot.angle}deg) scale(${LIFT_SCALE})`,
                }
              : undefined
          }
          onClick={handleClick}
          onMouseEnter={handleEnter}
          onMouseLeave={handleLeave}
        >
          <PlayingCard
            ref={tiltRef}
            name={card.name}
            deckStyle={deckStyle}
            size="hand"
            handle={card.h}
            motion={motion}
            onAnimationEnd={handleAnimationEnd}
          />
        </div>
      </div>
    </div>
  );
}
