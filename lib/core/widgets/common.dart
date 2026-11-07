import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// White rounded card used for every grouped block.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.border});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? context.scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: border,
        ),
        child: child,
      );
}

/// "1 · DEFAULT CURRENCY"-style caps label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final style = context.text.labelMedium?.copyWith(
      color: context.colors.muted,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text.rich(TextSpan(text: text.toUpperCase(), style: style, children: [
        if (trailing != null) TextSpan(text: ' · $trailing', style: style?.copyWith(fontWeight: FontWeight.w500)),
      ])),
    );
  }
}

/// Grey track with a white raised pill for the selected option (MTD | YTD).
class PillSegment<T> extends StatelessWidget {
  const PillSegment({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.expand = false,
    this.compact = false,
    this.colorFor,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool expand;
  final bool compact;
  final Color? Function(T)? colorFor;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final (value, label) in options)
        _pill(context, value, label, value == selected),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: context.colors.surfaceMuted, borderRadius: BorderRadius.circular(compact ? 12 : 16)),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: expand ? [for (final i in items) Expanded(child: i)] : items,
      ),
    );
  }

  Widget _pill(BuildContext context, T value, String label, bool on) {
    final fg = on ? (colorFor?.call(value) ?? context.scheme.onSurface) : context.colors.muted;
    return Semantics(
      selected: on,
      button: true,
      child: Material(
        color: on ? context.scheme.surface : Colors.transparent,
        elevation: on ? 1 : 0,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(compact ? 9 : 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(compact ? 9 : 12),
          onTap: () => onChanged(value),
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 32 : 40),
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
            alignment: Alignment.center,
            child: Text(label,
                style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: fg)),
          ),
        ),
      ),
    );
  }
}

/// Bordered choice chip; selected = soft teal fill.
class SelectChip extends StatelessWidget {
  const SelectChip({super.key, required this.label, required this.selected, required this.onTap, this.leading, this.tall = false});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.selectedBg : context.scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tall ? 16 : 12),
          side: BorderSide(color: selected ? context.scheme.primary : c.border, width: tall ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(tall ? 16 : 12),
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: tall ? 52 : 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? c.selected : context.scheme.onSurface,
                    )),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class ChipWrap extends StatelessWidget {
  const ChipWrap({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: children);
}

/// Small rounded status pill (PENDING, MAIN, RECEIVED…).
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, required this.fg, required this.bg});
  final String text;
  final Color fg, bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            style: context.text.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
      );
}

/// Thin horizontal progress bar (category share, credit utilisation).
class ShareBar extends StatelessWidget {
  const ShareBar({super.key, required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: fraction.clamp(0, 1),
          minHeight: 8,
          color: color,
          backgroundColor: context.colors.surfaceMuted,
        ),
      );
}

/// The ¢ logo tile + wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Brand.primary, borderRadius: BorderRadius.circular(size * 0.35)),
          child: Text('¢', style: figureStyle(size * 0.55, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Text('Centsible', style: figureStyle(size * 0.55)),
      ]);
}

class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, this.size = 40, this.index = 0});
  final String initials;
  final double size;
  final int index;

  static const _palette = [
    (Color(0xFF0E6B58), Colors.white),
    (Color(0xFFF5D9A8), Color(0xFF5C4310)),
    (Color(0xFFD7E1F5), Color(0xFF1E3F78)),
    (Color(0xFFFBEBE5), Color(0xFFA8432A)),
  ];

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _palette[index % _palette.length];
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: bg,
      child: Text(initials, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: size * 0.33)),
    );
  }
}

/// Book initial tile, coloured per book.
class BookTile extends StatelessWidget {
  const BookTile({super.key, required this.name, required this.colorIndex, this.size = 44});
  final String name;
  final int colorIndex;
  final double size;

  static const _palette = [
    (Color(0xFFCFE6DE), Color(0xFF0A4F41)),
    (Color(0xFFF5D9A8), Color(0xFF5C4310)),
    (Color(0xFFD7E1F5), Color(0xFF1E3F78)),
    (Color(0xFFEEF2F0), Color(0xFF10201B)),
  ];

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _palette[colorIndex % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: figureStyle(18, color: fg)),
    );
  }
}

/// Row inside a settings-style card: title, subtitle, trailing.
class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.title, this.subtitle, this.trailing, this.onTap, this.leading});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle!, style: context.text.bodySmall?.copyWith(color: context.colors.muted)),
              ]),
            ),
            if (trailing != null) trailing! else if (onTap != null) Icon(Icons.chevron_right, color: context.colors.muted),
          ]),
        ),
      );
}

/// Separates [children] with dividers inside a [SectionCard].
class RowGroup extends StatelessWidget {
  const RowGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SectionCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(children: [
            for (final (i, c) in children.indexed) ...[if (i > 0) const Divider(indent: 16, endIndent: 16), c],
          ]),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.body, this.action});
  final String title, body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(children: [
          Text(title, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(body, style: context.text.bodyMedium?.copyWith(color: context.colors.muted), textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ]),
      );
}
