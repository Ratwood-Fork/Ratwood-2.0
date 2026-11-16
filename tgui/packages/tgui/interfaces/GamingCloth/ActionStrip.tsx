import { Button } from 'tgui-core/components';

import type { DeckData, FeltCard } from './types';

type Props = {
  // The selected felt card, null for the deck's actions
  card: FeltCard | null;
  deck: DeckData;
  dealCount: number;
  isSeated: boolean;
};

/**
 * The strip under the felt. It shows the deck's actions, and the selected
 * felt card's while one is selected, so no button ever sits on the felt
 * where it would cover a different card for each viewer.
 */
export function ActionStrip(props: Props) {
  const { card, deck, dealCount, isSeated } = props;
  // Each strip has its own key, so selecting a card mounts new buttons. Reused ones would
  // ease their padding and margins to the new icons, laying out the window every frame
  if (card) {
    const isFaceDown = !card.name;
    return (
      <div key="card" className="GamingCloth__strip">
        <Button icon="retweet" disabled={!isSeated}>
          Flip
        </Button>
        <Button icon="redo" disabled={!isSeated}>
          Rotate
        </Button>
        {isFaceDown && (
          <Button icon="eye" disabled={!isSeated}>
            Peek
          </Button>
        )}
        <Button icon="hand-paper" disabled={!isSeated}>
          Take
        </Button>
        <Button icon="caret-down" iconPosition="right" disabled={!isSeated}>
          To Deck
        </Button>
      </div>
    );
  }
  const hasCards = !!deck?.present && deck.count > 0;
  return (
    <div key="deck" className="GamingCloth__strip">
      <Button icon="minus" compact disabled={!isSeated} />
      <Button disabled={!isSeated || !hasCards}>Deal {dealCount}</Button>
      <Button icon="plus" compact disabled={!isSeated} />
      <Button icon="clone" disabled={!isSeated || !hasCards}>
        Flip Top
      </Button>
      <Button icon="random" disabled={!isSeated || !deck?.present}>
        Shuffle
      </Button>
      <Button icon="layer-group" disabled={!isSeated || !deck?.present}>
        Collect
      </Button>
    </div>
  );
}
