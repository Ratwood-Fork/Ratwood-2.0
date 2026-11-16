/// Seats around one gaming cloth, numbered 1 bottom, 2 left, 3 top, 4 right in seat 1's view
#define GAMING_CLOTH_SEATS 4
/// Windows open on one cloth for viewers who hold no seat
#define GAMING_CLOTH_MAX_WATCHERS 8
/// Tiles a viewer may stand from the cloth and keep its window open
#define GAMING_CLOTH_WATCH_RANGE 5
/// Felt coordinates run 0 to this on both axes, the same numbers for every viewer
#define GAMING_CLOTH_FELT_SIZE 1000
/// Felt units kept clear at each edge, so a card's centre never sits closer to the rim than this
#define GAMING_CLOTH_EDGE_MARGIN 60
/// Table log entries sent in every payload
#define GAMING_CLOTH_EVENTS_KEPT 10
/// Actions one ops message may carry
#define GAMING_CLOTH_OPS_PER_MESSAGE 20
/// Shortest gap between two pushes of one cloth to its windows
#define GAMING_CLOTH_UPDATE_INTERVAL (0.2 SECONDS)
/// Shortest gap between two chat lines and sounds from one cloth
#define GAMING_CLOTH_ANNOUNCE_INTERVAL (1 SECONDS)
/// Shortest gap between two dice throws on one cloth
#define GAMING_CLOTH_THROW_INTERVAL (1.5 SECONDS)
/// Share of the configured topic limit a minute that one client's cloth window may spend
#define GAMING_CLOTH_ACT_SHARE 0.45
/// Most cards one deal action gives each seat
#define GAMING_CLOTH_DEAL_MAX 13
/// Dice one cloth holds, loose and from its bag together
#define GAMING_CLOTH_MAX_DICE 10
/// Most chips one chips action gives each seat
#define GAMING_CLOTH_CHIPS_DEAL_MAX 1000
/// Most chips a seat or the pot can hold
#define GAMING_CLOTH_CHIPS_MAX 100000
/// Button text of the deck prompt that sets up the rules-based card table
#define GAMING_CLOTH_PICK_TABLE "Card table"
/// Button text of the deck prompt that lays out a gaming cloth
#define GAMING_CLOTH_PICK_CLOTH "Gaming cloth"
/// A card in the game deck, sent to windows only as a count
#define CARD_ZONE_DECK 1
/// A card in a seat's hand, named only to that seat
#define CARD_ZONE_HAND 2
/// A card on the felt, named to all only while face up
#define CARD_ZONE_FELT 3
