import { useEffect, useRef } from 'react';

import { resolveAsset } from '../../assets';
import { pickSound, SLIP_SOUND, SOUND_FILES } from './sounds';

export type PlaySound = (name: string, volume?: number) => void;

/**
 * One Audio per file, cloned while every copy is busy, as the gallery's
 * sounds do. Files load once sound is first wanted. A muted window plays
 * nothing, and a play the browser refuses is dropped.
 */
export function useSoundPool(isMuted: boolean): PlaySound {
  const mutedNow = useRef(isMuted);
  mutedNow.current = isMuted;
  const pools = useRef<Record<string, HTMLAudioElement[]>>({});

  useEffect(() => {
    if (isMuted) {
      return;
    }
    for (const name of SOUND_FILES) {
      if (pools.current[name]) {
        continue;
      }
      const audio = new Audio(resolveAsset(name));
      audio.preload = 'auto';
      pools.current[name] = [audio];
    }
  }, [isMuted]);

  const idleAudio = (name: string) => {
    let pool = pools.current[name];
    if (!pool) {
      pool = [new Audio(resolveAsset(name))];
      pools.current[name] = pool;
    }
    const idle = pool.find((audio) => audio.paused);
    if (idle) {
      return idle;
    }
    const copy = pool[0].cloneNode() as HTMLAudioElement;
    pool.push(copy);
    return copy;
  };

  return (name, volume = 1) => {
    if (mutedNow.current) {
      return;
    }
    const chosen = pickSound(name, Math.random());
    const audio = idleAudio(chosen);
    audio.currentTime = 0;
    audio.volume = chosen === SLIP_SOUND ? 1 : volume;
    // A window that has not been interacted with refuses to play, which is not worth reporting
    audio.play().catch(() => {});
  };
}
