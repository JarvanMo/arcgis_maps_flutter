//
//  ArcGisServiceTable.swift
//  arcgis_maps_flutter
//
//  Created by Mo on 2022/7/18.
//

import Flutter
import ArcGIS

class ArcGisServiceTableController {
    private let messenger: FlutterBinaryMessenger
    private let methodChannel: FlutterMethodChannel
    private var serviceTables: [AGSServiceFeatureTable] = []

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        methodChannel = FlutterMethodChannel(name: "plugins.flutter.io/service_table", binaryMessenger: messenger)
        methodChannel.setMethodCallHandler(handle)
    }

    deinit {
        methodChannel.setMethodCallHandler(nil)
    }

    private func handle(_ call: FlutterMethodCall,
                        result: @escaping FlutterResult) -> Void {
        switch call.method {
        case "queryFeatures":
            queryFeatures(call, result: result)
            break
        case "queryFeatureCount":
            queryCount(call, result: result)
            break
        case "queryStatisticsAsync":
            queryStatisticsAsync(call, result: result)
            break
        default:
            result(FlutterMethodNotImplemented)
            break
        }
    }


    private func queryFeatures(_ call: FlutterMethodCall,
                               result: @escaping FlutterResult) {
        let emptyResult: Dictionary<String, Any> = ["features": [Any]()]
        guard let data = call.arguments as? Dictionary<String, Any> else {
            result(emptyResult)
            return
        }

        guard let url = URL(string: data["url"] as! String) else {
            result(emptyResult)
            return
        }


        guard let queryParameterMap = data["queryParameters"] as? Dictionary<String, Any> else {
            result(emptyResult)
            return
        }

        let whereClause: String? = queryParameterMap["whereClause"] as? String


        let geometryParam: Dictionary<String, Any>? = queryParameterMap["geometry"] as? Dictionary<String, Any>
        let spatialRelationShipParam: AGSSpatialRelationship? = strToSpatialRelationShip(string: queryParameterMap["spatialRelationship"] as? String)

        let query = AGSQueryParameters()

        query.returnGeometry = queryParameterMap["isReturnGeometry"] as? Bool ?? true
        query.maxFeatures = queryParameterMap["maxFeatures"] as! Int
        query.resultOffset = queryParameterMap["resultOffset"] as! Int

        if let g = geometryParam {
            query.geometry = AGSGeometry.fromFlutter(data: g)
        }

        if let w = whereClause {
            query.whereClause = w
        }

        if let srsp = spatialRelationShipParam {
            query.spatialRelationship = srsp
        }

        var queryFeatureFields: AGSQueryFeatureFields = AGSQueryFeatureFields.loadAll

        switch (data["url"] as? String) {
        case "IDS_ONLY":
            queryFeatureFields = AGSQueryFeatureFields.idsOnly
            break
        case "MINIMUM":
            queryFeatureFields = AGSQueryFeatureFields.minimum
            break
        case "LOAD_ALL":
            queryFeatureFields = AGSQueryFeatureFields.loadAll
            break
        default:
            break;
        }

//        [weak self]
        let serviceTable: AGSServiceFeatureTable = AGSServiceFeatureTable(url: url)
        serviceTables.append(serviceTable)
        serviceTable.queryFeatures(with: query, queryFeatureFields: queryFeatureFields) { [weak self](queryResult, error) in
            if let index = self?.serviceTables.firstIndex(of: serviceTable) {
                self?.serviceTables.remove(at: index)
            }
            if error != nil {
                result(emptyResult)
            } else {
                guard let features = queryResult?.featureEnumerator().allObjects else {
                    result(emptyResult)
                    return
                }
                let featuresJson = features.map { feature -> Any in
                    feature.toJSONFlutter()
                }
                result(["features": featuresJson])
            }
        }
    }

    private func queryStatisticsAsync(_ call: FlutterMethodCall,
                                      result: @escaping FlutterResult) {

        let emptyResult: Dictionary<String, [Dictionary<String, Any>]> = ["results": [Dictionary<String, Any>]()]
        guard let data = call.arguments as? Dictionary<String, Any> else {
            result(emptyResult)
            return
        }

        guard let url = URL(string: data["url"] as! String) else {
            result(emptyResult)
            return
        }


        guard let queryParametersMap = data["statisticsQueryParameters"] as? Dictionary<String, Any> else {
            result(emptyResult)
            return
        }

        let whereClause: String? = queryParametersMap["whereClause"] as? String

        let geometryParam: Dictionary<String, Any>? = queryParametersMap["geometry"] as? Dictionary<String, Any>
        let spatialRelationShipParam: AGSSpatialRelationship? = strToSpatialRelationShip(string: queryParametersMap["spatialRelationship"] as? String)

        let groupByFieldNamesParam: Array<String> = (queryParametersMap["groupByFieldNames"] as? Array<String> ?? [String]())

        let orderByFieldsParam = (queryParametersMap["orderByFields"] as? Array<Dictionary<String, String>> ?? []).map { e in
            var sortOrder: AGSSortOrder
            switch (e["sortOrder"]) {
            case "ASCENDING":
                sortOrder = AGSSortOrder.ascending
                break
            case "DESCENDING":
                sortOrder = AGSSortOrder.descending
                break
            default:
                sortOrder = AGSSortOrder.ascending
                break
            }
            return AGSOrderBy(fieldName: e["fieldName"] ?? "", sortOrder: sortOrder)
        }

        let statisticDefinitionsParam = (queryParametersMap["statisticDefinitions"] as? [Dictionary<String, String>] ?? [Dictionary<String, String>]()).map { dictionary -> AGSStatisticDefinition in
            AGSStatisticDefinition(onFieldName: dictionary["fieldName"] ?? "", statisticType: strToStaticType(string: dictionary["statisticType"]), outputAlias: dictionary["outputAlias"])
        }


        let statisticsQueryParameters = AGSStatisticsQueryParameters(statisticDefinitions: statisticDefinitionsParam)
        

        if let w = whereClause {
            statisticsQueryParameters.whereClause = w
        }

        if let g = geometryParam {
            statisticsQueryParameters.geometry = AGSGeometry.fromFlutter(data: g)
        }

        if let srsp = spatialRelationShipParam {
            statisticsQueryParameters.spatialRelationship = srsp
        }

        statisticsQueryParameters.groupByFieldNames.append(contentsOf: groupByFieldNamesParam)
        statisticsQueryParameters.orderByFields.append(contentsOf: orderByFieldsParam)

        let serviceTable: AGSServiceFeatureTable = AGSServiceFeatureTable(url: url)
        serviceTables.append(serviceTable)

        serviceTable.queryStatistics(with: statisticsQueryParameters) { [weak self](queryResult, error) in
            if let index = self?.serviceTables.firstIndex(of: serviceTable) {
                self?.serviceTables.remove(at: index)
            }
            if error != nil {
                result(emptyResult)
            } else {
                guard let statistics = queryResult?.statisticRecordEnumerator().allObjects else {
                    result(emptyResult)
                    return
                }

                var resultRecords: [[String: Any]] = [[String: Any]]();

                statistics.forEach { record in
                    var group: Dictionary<String, Any> = [String: Any]();
                    record.group.forEach { key, value in
                        if (value is String || value is NSNumber || value == nil) {
                            group[key] = value
                        }
                    }

                    var stat: Dictionary<String, Any> = [String: Any]();
                    record.statistics.forEach { key, value in
                        if (value is String || value is NSNumber || value == nil) {
                            stat[key] = value
                        }
                    }
                    resultRecords.append([
                        "group": group,
                        "statistics": stat
                    ])
                }

                result(["results": resultRecords])

            }
        }

    }


    private func queryCount(_ call: FlutterMethodCall,
                               result: @escaping FlutterResult) {
        let emptyResult: Dictionary<String, NSNumber> = ["count": 0]
        guard let data = call.arguments as? Dictionary<String, Any> else {
            result(emptyResult)
            return
        }

        guard let url = URL(string: data["url"] as! String) else {
            result(emptyResult)
            return
        }


        guard let queryParameterMap = data["queryParameters"] as? Dictionary<String, Any> else {
            result(emptyResult)
            return
        }

        let whereClause: String? = queryParameterMap["whereClause"] as? String


        let geometryParam: Dictionary<String, Any>? = queryParameterMap["geometry"] as? Dictionary<String, Any>
        let spatialRelationShipParam: AGSSpatialRelationship? = strToSpatialRelationShip(string: queryParameterMap["spatialRelationship"] as? String)

        let query = AGSQueryParameters()

        query.returnGeometry = queryParameterMap["isReturnGeometry"] as? Bool ?? true
        query.maxFeatures = queryParameterMap["maxFeatures"] as! Int
        query.resultOffset = queryParameterMap["resultOffset"] as! Int

        if let g = geometryParam {
            query.geometry = AGSGeometry.fromFlutter(data: g)
        }

        if let w = whereClause {
            query.whereClause = w
        }

        if let srsp = spatialRelationShipParam {
            query.spatialRelationship = srsp
        }


//        [weak self]
        let serviceTable: AGSServiceFeatureTable = AGSServiceFeatureTable(url: url)
        serviceTables.append(serviceTable)
        serviceTable.queryFeatureCount(with: query) { [weak self](queryResult, error) in
            if let index = self?.serviceTables.firstIndex(of: serviceTable) {
                self?.serviceTables.remove(at: index)
            }

            if error != nil {
                result(emptyResult)
            } else {
                result(["count": queryResult])
            }
        }
    }

    private func strToStaticType(string: String?) -> AGSStatisticType {
        var staticType: AGSStatisticType = AGSStatisticType.sum

        switch (string) {

        case "AVERAGE":
            staticType = AGSStatisticType.average
            break

        case "COUNT":
            staticType = AGSStatisticType.count
            break
        case "MAXIMUM":
            staticType = AGSStatisticType.maximum
            break
        case "MINIMUM":
            staticType = AGSStatisticType.minimum
            break
        case "STANDARD_DEVIATION":
            staticType = AGSStatisticType.standardDeviation
            break
        case "SUM":
            staticType = AGSStatisticType.sum
            break
            break
        case "VARIANCE":
            staticType = AGSStatisticType.variance
            break
        default:
            staticType = AGSStatisticType.sum
            break
        }

        return staticType

    }

    private func strToSpatialRelationShip(string: String?) -> AGSSpatialRelationship? {
        var spatialRelationShipParam: AGSSpatialRelationship? = nil

        switch (string) {

        case "UNKNOWN":
            spatialRelationShipParam = AGSSpatialRelationship.unknown
            break
        case "RELATE":
            spatialRelationShipParam = AGSSpatialRelationship.relate
            break
        case "EQUALS":
            spatialRelationShipParam = AGSSpatialRelationship.equals
            break
        case "DISJOINT":
            spatialRelationShipParam = AGSSpatialRelationship.disjoint
            break
        case "INTERSECTS":
            spatialRelationShipParam = AGSSpatialRelationship.intersects
            break
        case "CROSSES":
            spatialRelationShipParam = AGSSpatialRelationship.crosses
            break
        case "WITHIN":
            spatialRelationShipParam = AGSSpatialRelationship.within
            break
        case "CONTAINS":
            spatialRelationShipParam = AGSSpatialRelationship.contains
            break
        case "OVERLAPS":
            spatialRelationShipParam = AGSSpatialRelationship.overlaps
            break
        case "ENVELOPE_INTERSECTS":
            spatialRelationShipParam = AGSSpatialRelationship.envelopeIntersects
            break
        case "INDEX_INTERSECTS":
            spatialRelationShipParam = AGSSpatialRelationship.indexIntersects
            break
        default:
            spatialRelationShipParam = nil
            break
        }

        return spatialRelationShipParam

    }
}
