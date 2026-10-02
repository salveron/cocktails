/// `counted` — a count and a noun, pluralised with an 's': singular only at
/// exactly one, plural everywhere else, 0 included.
library;

/// What joins the parts of a one-line summary, wherever one is written.
const String beside = ' · ';

String counted(int count, String noun) =>
    '$count $noun${count == 1 ? '' : 's'}';
