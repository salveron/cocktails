/// The bulleted runs an `EntryCard`'s body counts things in — an arriving
/// file's vocabularies (ADR 07) and a basket's two halves alike
/// (docs/ui-design.md#vocabulary-editing).
library;

import 'package:flutter/material.dart';

typedef Bullet = ({String name, Widget? trailing});

/// One stretch of bullets under a heading, the heading being null wherever the
/// run stands alone and needs none. [onTap] is where the run's names are kept —
/// one destination for the run, a run being the names of a single kind (ADR 19).
typedef BulletRun = ({
  String? label,
  List<Bullet> bullets,
  void Function(String name)? onTap,
});

BulletRun bulletRun(Iterable<String> names, {String? label}) => (
  label: label,
  bullets: [for (final name in names) (name: name, trailing: null)],
  onTap: null,
);

/// Every name an `EntryCard`'s body counts, bulleted under the run it falls
/// in. An empty run is left out rather than standing as a heading over
/// nothing.
class BulletRuns extends StatelessWidget {
  const BulletRuns(this.runs, {super.key});

  final List<BulletRun> runs;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final run in runs.where((run) => run.bullets.isNotEmpty)) ...[
        if (run.label case final label?)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
        for (final bullet in run.bullets) _BulletLine(run: run, bullet: bullet),
      ],
    ],
  );
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.run, required this.bullet});

  final BulletRun run;
  final Bullet bullet;

  @override
  Widget build(BuildContext context) {
    final line = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Flexible(child: Text('• ${bullet.name}')),
          if (bullet.trailing case final mark?)
            Padding(padding: const EdgeInsets.only(left: 6), child: mark),
        ],
      ),
    );
    final onTap = run.onTap;
    return onTap == null
        ? line
        : InkWell(onTap: () => onTap(bullet.name), child: line);
  }
}
