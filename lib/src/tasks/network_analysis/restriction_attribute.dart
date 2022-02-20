part of arcgis_maps_flutter;

@immutable
class RestrictionAttribute {
  const RestrictionAttribute._({
    this.parameterValues,
    required this.restrictionUsageParameterName,
  });

  factory RestrictionAttribute.fromJson(Map<dynamic, dynamic> json) {
    return RestrictionAttribute._(
      parameterValues: parseAttributes(json['parameterValues']),
      restrictionUsageParameterName: json['restrictionUsageParameterName'],
    );
  }

  final Map<String, Object?>? parameterValues;
  final String restrictionUsageParameterName;

  @override
  String toString(){
    return 'RestrictionAttribute{parameterValues: $parameterValues, restrictionUsageParameterName: $restrictionUsageParameterName}';
  }
}
