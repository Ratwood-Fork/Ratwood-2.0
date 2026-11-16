/**
 * The table's sounds, as /datum/asset/simple/gaming_cloth_sounds sends
 * them, and the gallery's rare slip in place of any of them.
 */
export const LAND_SOUND = 'gaming_cloth_land.ogg';
export const TURN_SOUND = 'gaming_cloth_turn.ogg';
export const SLIP_SOUND = 'gaming_cloth_slip.ogg';

export const SOUND_FILES = [LAND_SOUND, TURN_SOUND, SLIP_SOUND];

/** The gallery's chance that a sound comes out as the slip instead */
export const SLIP_CHANCE = 0.01;

/** Volumes from the gallery: a card on its own and each of several dealt at once */
export const CLICK_VOLUME = 0.83;
export const DEALT_VOLUME = 0.58;

/** The file to play for a sound, given a roll from 0 to 1 */
export function pickSound(name: string, roll: number): string {
  return roll < SLIP_CHANCE ? SLIP_SOUND : name;
}
