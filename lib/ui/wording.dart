/// `counted` — a count and a noun, pluralised with an 's': singular only at
/// exactly one, plural everywhere else, 0 included.
library;

String counted(int count, String noun) =>
    '$count $noun${count == 1 ? '' : 's'}';
