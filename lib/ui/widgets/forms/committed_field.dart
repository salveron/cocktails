import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import 'editor_form.dart';
import 'field_issues.dart';

/// A name settled where it stands, with no Save beside it
/// (docs/ui-design.md#sharing): leaving the field is the commit, and a field left blank — or one [validate]
/// refuses — gives back the name that stood rather than leaving nothing, or
/// something refused, behind. A field only looked at commits nothing, and a
/// reader who typed and went straight back keeps what they typed.
///
/// [initial] is read once: the field is the reader's from there, and a rebuild
/// must not put back what they are in the middle of typing. [onCommit] runs from
/// `dispose` too, so it must reach what it commits to without a `ref`.
class CommittedField extends StatefulWidget {
  const CommittedField({
    required this.initial,
    required this.hintText,
    required this.onCommit,
    this.validate,
    this.enabled = true,
    super.key,
  });

  final String initial;
  final String hintText;
  final ValueChanged<String> onCommit;

  /// The issues a typed name has, for the field to show and the commit to wait
  /// on; none where any non-blank name will do.
  final List<ValidationIssue> Function(String typed)? validate;
  final bool enabled;

  @override
  State<CommittedField> createState() => _CommittedFieldState();
}

class _CommittedFieldState extends State<CommittedField>
    with AutomaticKeepAliveClientMixin {
  final _name = TextEditingController();
  final _focus = FocusNode();

  /// The last name this field put on the record, or what it opened with until
  /// then — so a visit renames nothing.
  late String _committed;

  @override
  void initState() {
    super.initState();
    _committed = widget.initial;
    _name.text = _committed;
    _name.addListener(() => setState(() {}));
    _focus.addListener(_leftTheField);
  }

  @override
  void dispose() {
    _commit();
    // Off first: a field torn down while focused must not be told it let go.
    _focus.removeListener(_leftTheField);
    _focus.dispose();
    _name.dispose();
    super.dispose();
  }

  List<ValidationIssue> get _issues => widget.validate?.call(_name.typed) ?? [];

  bool get _commits =>
      !_name.isBlank && _issues.isEmpty && _name.typed != _committed;

  void _commit() {
    if (!_commits) return;
    _committed = _name.typed;
    widget.onCommit(_committed);
  }

  void _leftTheField() {
    if (_focus.hasFocus) return;
    if (_name.isBlank || _issues.isNotEmpty) {
      _name.text = _committed;
      return;
    }
    _commit();
  }

  /// Kept alive inside a scrolling list: a field scrolled out and back would
  /// otherwise start again from [CommittedField.initial], which is what it
  /// opened with and no longer what stands.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TextField(
      controller: _name,
      focusNode: _focus,
      enabled: widget.enabled,
      decoration: InputDecoration(
        hintText: widget.hintText,
        errorText: fieldError(_name.typed, _issues),
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _focus.unfocus(),
    );
  }
}
