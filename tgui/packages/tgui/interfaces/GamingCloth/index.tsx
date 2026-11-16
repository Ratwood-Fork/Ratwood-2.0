import { useRef, useState } from 'react';
import { Button, Section, Stack } from 'tgui-core/components';
import { UI_INTERACTIVE } from 'tgui-core/constants';

import { useBackend } from '../../backend';
import { Window } from '../../layouts';
import { ActionStrip } from './ActionStrip';
import { sortHand, SortMode } from './cards';
import { Felt } from './Felt';
import { Hand } from './Hand';
import { SeatLabel, SeatList } from './Seats';
import { TableLog } from './TableLog';
import type { GamingClothData, SeatData } from './types';
import { useCandleFlicker } from './useCandleFlicker';
import { useEvents } from './useEvents';
import { useSoundPool } from './useSoundPool';
import { seatSide, viewAngle } from './view';

/**
 * A freeform card table. Each viewer gets their own payload and sees the
 * felt turned so their own seat is at the bottom.
 */
export function GamingCloth() {
  const { config } = useBackend<GamingClothData>();
  return (
    <Window width={900} height={720}>
      <Window.Content fitted>
        <ClothTable key={config.window?.key} />
      </Window.Content>
    </Window>
  );
}

/**
 * Holds all of the window's own state. tgui pools its pages, so a page
 * outlives one cloth. Keyed by the window key, this component starts fresh
 * for each cloth and keeps nothing from the last.
 */
function ClothTable() {
  const { config, data } = useBackend<GamingClothData>();
  // Selection never leaves the window, so no other player sees it
  const [selectedFelt, setSelectedFelt] = useState<number | null>(null);
  const [selectedHand, setSelectedHand] = useState<number | null>(null);
  const [sortMode] = useState(SortMode.Dealt);
  const [isFaceDown] = useState(false);
  const [dealCount] = useState(1);
  const [isMuted, setMuted] = useState(false);

  const you = data.you || 0;
  const angle = viewAngle(you);
  const rootRef = useRef<HTMLDivElement>(null);
  const play = useSoundPool(isMuted);
  // The seen-event mark lives here, so a page reused for another cloth starts a new one
  useEvents(rootRef, data, angle, play);
  const glowRef = useCandleFlicker(rootRef);
  const seats: SeatData[] = data.seats || [];
  const felt = data.felt || [];
  const hand = sortHand(data.hand || [], sortMode);
  const deckStyle = data.deck?.style;
  const isInteractive = config.status === UI_INTERACTIVE;
  const isSeated = you > 0 && isInteractive;
  const isShowing = !!seats[you - 1]?.showing;
  // A selected card that has left the felt or the hand is simply not drawn lifted
  const selectedCard = felt.find((card) => card.h === selectedFelt) ?? null;

  const handleSelectFelt = (handle: number) =>
    setSelectedFelt(handle === selectedFelt ? null : handle);
  const handleSelectHand = (handle: number) =>
    setSelectedHand(handle === selectedHand ? null : handle);
  const handleClearFelt = () => {
    setSelectedFelt(null);
    setSelectedHand(null);
  };
  const handleClearHand = () => setSelectedHand(null);
  const handleToggleMute = () => setMuted(!isMuted);

  return (
    <div className="GamingCloth" ref={rootRef}>
      <div className="GamingCloth__main">
        <div className="GamingCloth__tableArea">
          <div className="GamingCloth__table">
            {seats.map((seat, index) => (
              <SeatLabel
                key={index + 1}
                seat={index + 1}
                data={seat}
                side={seatSide(index + 1, you)}
                isYou={index + 1 === you}
                deckStyle={deckStyle}
              />
            ))}
            <Felt
              felt={felt}
              deck={data.deck}
              peeks={data.peeks}
              angle={angle}
              selected={selectedFelt}
              glowRef={glowRef}
              onSelectCard={handleSelectFelt}
              onClearSelection={handleClearFelt}
            />
          </div>
        </div>
        <ActionStrip
          card={selectedCard}
          deck={data.deck}
          dealCount={dealCount}
          isSeated={isSeated}
        />
        <Hand
          hand={hand}
          deckStyle={deckStyle}
          isSeated={you > 0}
          selected={selectedHand}
          sortMode={sortMode}
          isFaceDown={isFaceDown}
          onSelectCard={handleSelectHand}
          onClearSelection={handleClearHand}
        />
      </div>
      <div className="GamingCloth__side">
        <Stack vertical fill>
          <Stack.Item>
            <Section title="Seats">
              <SeatList seats={seats} you={you} isInteractive={isInteractive} />
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            <Section title="Table log" fill scrollable>
              <TableLog events={data.events} />
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Stack>
              <Stack.Item grow>
                <Button fluid icon="eye" disabled={!isSeated}>
                  {isShowing ? 'Hide Hand' : 'Show Hand'}
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon={isMuted ? 'volume-mute' : 'volume-up'}
                  selected={isMuted}
                  onClick={handleToggleMute}
                />
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item>
            <Button fluid icon="box" disabled={!isSeated}>
              Pack Up
            </Button>
          </Stack.Item>
        </Stack>
      </div>
    </div>
  );
}
