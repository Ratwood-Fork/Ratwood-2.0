import { classes } from 'tgui-core/react';

import { backStyle } from './cards';
import { OnFelt } from './OnFelt';
import { DECK_SPOT, type DeckData } from './types';

type Props = {
  deck: DeckData;
  angle: number;
};

/** The deck at its fixed spot, a pile of backs with its count upright on it */
export function Deck(props: Props) {
  const { deck, angle } = props;
  if (!deck?.present) {
    return null;
  }
  const isEmpty = deck.count <= 0;
  return (
    <OnFelt
      x={DECK_SPOT.x}
      y={DECK_SPOT.y}
      rot={0}
      angle={angle}
      depth={0}
      motion="deck"
    >
      <div
        className={classes([
          'GamingCloth__deck',
          isEmpty
            ? 'GamingCloth__deck--empty'
            : `GamingCloth__back--${backStyle(deck.style)}`,
        ])}
      >
        <span className="GamingCloth__deckCount">{deck.count}</span>
      </div>
    </OnFelt>
  );
}
