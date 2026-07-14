/// Fonds de carte — parité avec frontend/js/map.js (L.control.layers).
enum BasemapType {
  osm,
  satellite,
  topo,
}

extension BasemapTypeExt on BasemapType {
  /// Libellés web : OpenStreetMap · Satellite · Topographique
  String get label {
    switch (this) {
      case BasemapType.osm:
        return 'OpenStreetMap';
      case BasemapType.satellite:
        return 'Satellite';
      case BasemapType.topo:
        return 'Topographique';
    }
  }

  String get shortLabel {
    switch (this) {
      case BasemapType.osm:
        return 'OSM';
      case BasemapType.satellite:
        return 'Sat.';
      case BasemapType.topo:
        return 'Topo';
    }
  }

  String get urlTemplate {
    switch (this) {
      case BasemapType.osm:
        return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
      case BasemapType.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case BasemapType.topo:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
    }
  }

  List<String>? get subdomains {
    switch (this) {
      case BasemapType.osm:
      case BasemapType.topo:
        return const ['a', 'b', 'c'];
      case BasemapType.satellite:
        return null;
    }
  }
}
