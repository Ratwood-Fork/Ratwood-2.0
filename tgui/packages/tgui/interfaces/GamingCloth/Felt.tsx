import type { MouseEvent, RefObject } from 'react';

import { Deck } from './Deck';
import { liftOffset } from './geometry';
import { OnFelt } from './OnFelt';
import { PlayingCard } from './PlayingCard';
import type { DeckData, FeltCard } from './types';
import { useFaceMotion } from './useFaceMotion';
import { useTilt } from './useTilt';

type Props = {
  felt: FeltCard[];
  deck: DeckData;
  peeks: Record<string, string>;
  angle: number;
  selected: number | null;
  glowRef: RefObject<HTMLDivElement | null>;
  onSelectCard: (handle: number) => void;
  onClearSelection: () => void;
};

/** Raises the selected card's anchor above every other thing on the felt */
const SELECTED_DEPTH = 10000;

/** The name a viewer peeked at, with an empty peeks arriving as [] */
function peekedName(
  peeks: Record<string, string>,
  handle: number,
): string | null {
  if (!peeks || Array.isArray(peeks)) {
    return null;
  }
  return peeks[String(handle)] ?? null;
}

/**
 * The square felt. The box never turns and carries the colour, edge and
 * light. The layer inside it turns by the viewer's angle and holds only the
 * things on the table, each placed in table coordinates.
 */
export function Felt(props: Props) {
  const {
    felt,
    deck,
    peeks,
    angle,
    selected,
    glowRef,
    onSelectCard,
    onClearSelection,
  } = props;

  const handleFeltClick = () => onClearSelection();

  return (
    <div className="GamingCloth__felt" onClick={handleFeltClick}>
      <div ref={glowRef} className="GamingCloth__glow" />
      <div
        className="GamingCloth__layer"
        style={{ transform: `rotate(${angle}deg)` }}
      >
        <Deck deck={deck} angle={angle} />
        {felt.map((card, index) => {
          const isSelected = card.h === selected;
          // A face-down card the viewer peeked at shows its face only while lifted
          const shownName =
            card.name ?? (isSelected ? peekedName(peeks, card.h) : null);
          return (
            <FeltCardView
              key={card.h}
              card={card}
              shownName={shownName}
              deckStyle={deck?.style}
              angle={angle}
              depth={isSelected ? SELECTED_DEPTH : index + 1}
              isSelected={isSelected}
              onSelect={onSelectCard}
            />
          );
        })}
      </div>
    </div>
  );
}

type CardProps = {
  card: FeltCard;
  shownName: string | null;
  deckStyle: string;
  angle: number;
  depth: number;
  isSelected: boolean;
  onSelect: (handle: number) => void;
};

/** One card on the felt, which hops as it is lifted and leans toward the pointer while up */
function FeltCardView(props: CardProps) {
  const { card, shownName, deckStyle, angle, depth, isSelected, onSelect } =
    props;
  const { motion, handleAnimationEnd } = useFaceMotion(isSelected);
  const tiltRef = useTilt(isSelected, card.rot);

  const handleClick = (event: MouseEvent<HTMLDivElement>) => {
    event.stopPropagation();
    onSelect(card.h);
  };

  return (
    <OnFelt
      x={card.x}
      y={card.y}
      rot={card.rot}
      angle={angle}
      depth={depth}
      motion={`card-${card.h}`}
      lift={isSelected ? liftOffset(card.x, card.y, card.rot, angle) : null}
    >
      <PlayingCard
        ref={tiltRef}
        name={shownName}
        deckStyle={deckStyle}
        size="felt"
        handle={card.h}
        motion={motion}
        onClick={handleClick}
        onAnimationEnd={handleAnimationEnd}
      />
    </OnFelt>
  );
}
