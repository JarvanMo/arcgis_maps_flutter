part of arcgis_maps_flutter;

@immutable
abstract class GeoElement {
  /// Attribute types supported are null, String, Date, and Numbers.
  /// Other attribute types will be ignored.
  Map<String, Object?> get attributes;

  Geometry? get geometry;

  factory GeoElement.fromJson(Map<dynamic, dynamic> json) {
    final Map<String, Object?> attributes = parseAttributes(json['attributes']) ?? {};

    Geometry? geometry;

    geometry = Geometry.fromJson(json['geometry']);

    return _GeoElementImpl(attributes, geometry);
  }

  GeoElement copyWith({
    Map<String, Object?>? attributesParam,
    Geometry? geometryParam,
  });
}

class _GeoElementImpl implements GeoElement {
  final Map<String, Object?> _attributes;
  final Geometry? _geometry;

  _GeoElementImpl(this._attributes, this._geometry);

  @override
  Map<String, Object?> get attributes => _attributes;

  @override
  Geometry? get geometry => _geometry;

  @override
  GeoElement copyWith({
    Map<String, Object?>? attributesParam,
    Geometry? geometryParam,
  }) {
    return _GeoElementImpl(
      attributesParam ?? _attributes,
      geometryParam ?? _geometry,
    );
  }
}
