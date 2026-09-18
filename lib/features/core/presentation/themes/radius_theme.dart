import 'package:material_ui/material_ui.dart';

@immutable
class const CornerRadiusToken({
  required final BorderRadius cornerRadius050,
  required final BorderRadius cornerRadius100,
  required final BorderRadius cornerRadius300,
  required final BorderRadius cornerRadius500,
  required final BorderRadius cornerRadius700,
  required final BorderRadius cornerRadiusFull,
}) extends ThemeExtension<CornerRadiusToken> {
  @override
  CornerRadiusToken copyWith({
    BorderRadius? cornerRadius050,
    BorderRadius? cornerRadius100,
    BorderRadius? cornerRadius300,
    BorderRadius? cornerRadius500,
    BorderRadius? cornerRadius700,
    BorderRadius? cornerRadiusFull,
  }) => CornerRadiusToken(
    cornerRadius050: cornerRadius050 ?? this.cornerRadius050,
    cornerRadius100: cornerRadius100 ?? this.cornerRadius100,
    cornerRadius300: cornerRadius300 ?? this.cornerRadius300,
    cornerRadius500: cornerRadius500 ?? this.cornerRadius500,
    cornerRadius700: cornerRadius700 ?? this.cornerRadius700,
    cornerRadiusFull: cornerRadiusFull ?? this.cornerRadiusFull,
  );

  @override
  CornerRadiusToken lerp(ThemeExtension<CornerRadiusToken>? other, double t) =>
      other is! CornerRadiusToken
      ? this
      : CornerRadiusToken(
          cornerRadius050: .lerp(cornerRadius050, other.cornerRadius050, t)!,
          cornerRadius100: .lerp(cornerRadius100, other.cornerRadius100, t)!,
          cornerRadius300: .lerp(cornerRadius300, other.cornerRadius300, t)!,
          cornerRadius500: .lerp(cornerRadius500, other.cornerRadius500, t)!,
          cornerRadius700: .lerp(cornerRadius700, other.cornerRadius700, t)!,
          cornerRadiusFull: .lerp(cornerRadiusFull, other.cornerRadiusFull, t)!,
        );
}

const radius = CornerRadiusToken(
  cornerRadius050: .only(
    topLeft: Radius.circular(12.0),
    topRight: Radius.circular(12.0),
    bottomLeft: Radius.circular(12.0),
    bottomRight: Radius.circular(12.0),
  ),
  cornerRadius100: .only(
    topLeft: Radius.circular(14.0),
    topRight: Radius.circular(14.0),
    bottomLeft: Radius.circular(14.0),
    bottomRight: Radius.circular(14.0),
  ),
  cornerRadius300: .only(
    topLeft: Radius.circular(20.0),
    topRight: Radius.circular(20.0),
    bottomLeft: Radius.circular(20.0),
    bottomRight: Radius.circular(20.0),
  ),
  cornerRadius500: .only(
    topLeft: Radius.circular(28.0),
    topRight: Radius.circular(28.0),
    bottomLeft: Radius.circular(28.0),
    bottomRight: Radius.circular(28.0),
  ),
  cornerRadius700: .only(
    topLeft: Radius.circular(36.0),
    topRight: Radius.circular(36.0),
    bottomLeft: Radius.circular(36.0),
    bottomRight: Radius.circular(36.0),
  ),
  cornerRadiusFull: .only(
    topLeft: Radius.circular(50.0),
    topRight: Radius.circular(50.0),
    bottomLeft: Radius.circular(50.0),
    bottomRight: Radius.circular(50.0),
  ),
);
