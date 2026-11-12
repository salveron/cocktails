library;

/// What joins the parts of a one-line summary, wherever one is written.
const String beside = ' · ';

String counted(int count, String noun) =>
    '$count $noun${count == 1 ? '' : 's'}';
