import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

/// The one map widget every screen uses: Google Maps (Maps SDK for Android /
/// iOS), behind an API shaped like the flutter_map code it replaced, so
/// screens keep their latlong2 `LatLng`s and their own marker widgets.
///
/// OpenStreetMap's public tile servers, which the screens used before, don't
/// allow production app traffic. Google's mobile maps are free to display.
///
/// Marker widgets are drawn to images once and cached by [MapMarker.key]
/// (Google markers are images, not widgets), so a marker that only moves —
/// the driver on live tracking — is never redrawn.

/// A marker: any widget, drawn at [width] x [height] logical pixels.
class MapMarker {
  /// Unique within the map.
  final String id;
  final LatLng point;
  final double width;
  final double height;

  /// Where the marker sits relative to [point], as in flutter_map: center
  /// puts the point in the middle, topCenter puts the marker above the point
  /// (pin tip at the bottom).
  final Alignment alignment;

  /// Identifies the marker's look. Markers with the same key share one image,
  /// so give each distinct look its own key (e.g. 'pickup', 'stop-2').
  final String key;
  final Widget child;
  final VoidCallback? onTap;

  const MapMarker({
    required this.id,
    required this.point,
    required this.key,
    required this.child,
    this.width = 40,
    this.height = 40,
    this.alignment = Alignment.center,
    this.onTap,
  });
}

/// A line along [points] (a route), [width] in logical pixels.
class MapLine {
  final String id;
  final List<LatLng> points;
  final Color color;
  final double width;
  final bool dashed;

  const MapLine({
    required this.id,
    required this.points,
    required this.color,
    this.width = 4,
    this.dashed = false,
  });
}

/// A circle of [radiusMeters] around [center] (e.g. a search radius).
class MapCircle {
  final String id;
  final LatLng center;
  final double radiusMeters;
  final Color color;
  final Color borderColor;
  final double borderWidth;

  const MapCircle({
    required this.id,
    required this.center,
    required this.radiusMeters,
    required this.color,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0,
  });
}

/// Moves the map from the screen's code (search result picked, driver moved).
class MovezyMapController {
  gm.GoogleMapController? _map;
  LatLng _center = const LatLng(0, 0);
  double _zoom = 14;

  /// Set while the camera moves because the code moved it, so camera
  /// callbacks can tell a user's drag from a programmatic move.
  bool _programmatic = false;

  /// A move asked for before the map existed (a GPS fix that beat the map's
  /// creation); applied as soon as it does.
  (LatLng, double)? _pendingMove;

  /// Uneven edge insets from [fitPoints] (a sheet covering the lower part of
  /// the map). They become the map's padding, so framing, the camera centre
  /// and Google's logo all stay in the uncovered area.
  final ValueNotifier<EdgeInsets?> _insets = ValueNotifier(null);

  LatLng get center => _center;
  double get zoom => _zoom;
  bool get isReady => _map != null;

  void _attach(gm.GoogleMapController map, LatLng center, double zoom) {
    _map = map;
    _center = center;
    _zoom = zoom;
    final pending = _pendingMove;
    _pendingMove = null;
    if (pending != null) move(pending.$1, pending.$2);
  }

  void move(LatLng point, double zoom, {bool animate = false}) {
    final map = _map;
    if (map == null) {
      _pendingMove = (point, zoom);
      return;
    }
    _programmatic = true;
    final update = gm.CameraUpdate.newLatLngZoom(_g(point), zoom);
    animate ? map.animateCamera(update) : map.moveCamera(update);
  }

  /// Frames every point with [padding] logical pixels around them, inside
  /// [insets] when given (uneven margins, e.g. above a bottom sheet).
  void fitPoints(List<LatLng> points,
      {double padding = 48,
      EdgeInsets? insets,
      double maxZoom = 16,
      bool animate = false}) {
    final map = _map;
    if (map == null || points.isEmpty) return;
    void apply() {
      _programmatic = true;
      final update = _fitUpdate(points, padding, maxZoom);
      animate ? map.animateCamera(update) : map.moveCamera(update);
    }

    if (insets != null && insets != _insets.value) {
      // The new padding has to reach the map before the camera fits to it.
      _insets.value = insets;
      Future<void>.delayed(const Duration(milliseconds: 80), apply);
    } else {
      apply();
    }
  }
}

gm.LatLng _g(LatLng p) => gm.LatLng(p.latitude, p.longitude);
LatLng _l(gm.LatLng p) => LatLng(p.latitude, p.longitude);

gm.CameraUpdate _fitUpdate(List<LatLng> points, double padding, double maxZoom) {
  var minLat = points.first.latitude, maxLat = minLat;
  var minLng = points.first.longitude, maxLng = minLng;
  for (final p in points) {
    minLat = math.min(minLat, p.latitude);
    maxLat = math.max(maxLat, p.latitude);
    minLng = math.min(minLng, p.longitude);
    maxLng = math.max(maxLng, p.longitude);
  }
  // One point (or all the same): bounds would be empty, so just centre on it.
  if ((maxLat - minLat).abs() < 1e-6 && (maxLng - minLng).abs() < 1e-6) {
    return gm.CameraUpdate.newLatLngZoom(gm.LatLng(minLat, minLng), maxZoom);
  }
  return gm.CameraUpdate.newLatLngBounds(
    gm.LatLngBounds(
      southwest: gm.LatLng(minLat, minLng),
      northeast: gm.LatLng(maxLat, maxLng),
    ),
    padding,
  );
}

class MovezyMap extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final double maxZoom;

  /// When set, the map opens framed on these points instead of
  /// [initialCenter]/[initialZoom], [fitPadding] around them, inside
  /// [fitInsets] when given.
  final List<LatLng>? fitPoints;
  final double fitPadding;
  final EdgeInsets? fitInsets;

  /// False for preview maps the user can't pan or zoom.
  final bool interactive;

  final List<MapMarker> markers;
  final List<MapLine> lines;
  final List<MapCircle> circles;
  final MovezyMapController? controller;

  /// Every camera change: centre, zoom, and whether the user moved it.
  final void Function(LatLng center, double zoom, bool byUser)? onCameraMove;

  /// The camera stopped: end of a drag (byUser) or of a programmatic move.
  final void Function(LatLng center, double zoom, bool byUser)? onCameraIdle;
  final VoidCallback? onMapReady;

  /// Space kept clear at the edges (for overlaid panels), so Google's logo
  /// and the framing stay visible.
  final EdgeInsets padding;

  const MovezyMap({
    super.key,
    required this.initialCenter,
    this.initialZoom = 14,
    this.maxZoom = 18,
    this.fitPoints,
    this.fitPadding = 48,
    this.fitInsets,
    this.interactive = true,
    this.markers = const [],
    this.lines = const [],
    this.circles = const [],
    this.controller,
    this.onCameraMove,
    this.onCameraIdle,
    this.onMapReady,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<MovezyMap> createState() => _MovezyMapState();
}

class _MovezyMapState extends State<MovezyMap> {
  /// Marker images by look (MapMarker.key + size), shared by every map.
  static final Map<String, gm.BitmapDescriptor> _icons = {};
  static final Map<String, Future<void>> _pending = {};

  late final MovezyMapController _controller =
      widget.controller ?? MovezyMapController();
  late LatLng _center = widget.initialCenter;
  late double _zoom = widget.initialZoom;

  @override
  void initState() {
    super.initState();
    if (widget.fitInsets != null) _controller._insets.value = widget.fitInsets;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareIcons();
  }

  @override
  void didUpdateWidget(covariant MovezyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepareIcons();
  }

  String _iconKey(MapMarker m) => '${m.key}@${m.width}x${m.height}';

  /// Draws any marker look not drawn yet, then rebuilds to show it.
  void _prepareIcons() {
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    for (final m in widget.markers) {
      final key = _iconKey(m);
      if (_icons.containsKey(key) || _pending.containsKey(key)) continue;
      _pending[key] = _drawMarker(m, ratio).then((bytes) {
        if (bytes != null) {
          _icons[key] = gm.BytesMapBitmap(
            bytes,
            width: m.width,
            height: m.height,
            imagePixelRatio: ratio,
          );
        }
      }).whenComplete(() {
        _pending.remove(key);
        if (mounted) setState(() {});
      });
    }
  }

  /// Renders the marker widget off-screen to a PNG at the device's density.
  static Future<Uint8List?> _drawMarker(MapMarker m, double ratio) async {
    try {
      final size = Size(m.width, m.height);
      final boundary = RenderRepaintBoundary();
      final view = ui.PlatformDispatcher.instance.implicitView ??
          ui.PlatformDispatcher.instance.views.first;
      final renderView = RenderView(
        view: view,
        child: RenderPositionedBox(alignment: Alignment.center, child: boundary),
        configuration: ViewConfiguration(
          logicalConstraints: BoxConstraints.tight(size),
          physicalConstraints: BoxConstraints.tight(size * ratio),
          devicePixelRatio: ratio,
        ),
      );
      final pipeline = PipelineOwner()..rootNode = renderView;
      renderView.prepareInitialFrame();
      final buildOwner = BuildOwner(focusManager: FocusManager());
      final root = RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
        child: MediaQuery(
          data: MediaQueryData(size: size, devicePixelRatio: ratio),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.black, fontSize: 12),
              child: SizedBox.fromSize(size: size, child: Center(child: m.child)),
            ),
          ),
        ),
      ).attachToRenderTree(buildOwner);
      buildOwner.buildScope(root);
      buildOwner.finalizeTree();
      pipeline.flushLayout();
      pipeline.flushCompositingBits();
      pipeline.flushPaint();
      final image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (e) {
      debugPrint('map: marker draw failed for ${m.key}: $e');
      return null;
    }
  }

  Set<gm.Marker> _markers() => {
        for (final m in widget.markers)
          if (_icons[_iconKey(m)] != null)
            gm.Marker(
              markerId: gm.MarkerId(m.id),
              position: _g(m.point),
              icon: _icons[_iconKey(m)]!,
              // flutter_map alignment → Google anchor (fraction of the image
              // that sits on the point).
              anchor: Offset((1 - m.alignment.x) / 2, (1 - m.alignment.y) / 2),
              consumeTapEvents: m.onTap != null,
              onTap: m.onTap,
            ),
      };

  Set<gm.Polyline> _polylines(double ratio) => {
        for (final l in widget.lines)
          if (l.points.length >= 2)
            gm.Polyline(
              polylineId: gm.PolylineId(l.id),
              points: l.points.map(_g).toList(),
              color: l.color,
              // Google sizes lines in physical pixels.
              width: math.max(1, (l.width * ratio).round()),
              patterns: l.dashed
                  ? [gm.PatternItem.dash(20), gm.PatternItem.gap(12)]
                  : const <gm.PatternItem>[],
              jointType: gm.JointType.round,
              startCap: gm.Cap.roundCap,
              endCap: gm.Cap.roundCap,
            ),
      };

  Set<gm.Circle> _circles(double ratio) => {
        for (final c in widget.circles)
          gm.Circle(
            circleId: gm.CircleId(c.id),
            center: _g(c.center),
            radius: c.radiusMeters,
            fillColor: c.color,
            strokeColor: c.borderColor,
            strokeWidth: (c.borderWidth * ratio).round(),
          ),
      };

  Future<void> _onCreated(gm.GoogleMapController map) async {
    _controller._attach(map, _center, _zoom);
    final fit = widget.fitPoints;
    if (fit != null && fit.isNotEmpty) {
      // Bounds need the map laid out; one short beat avoids a zero-size fit.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      _controller.fitPoints(fit,
          padding: widget.fitPadding, maxZoom: widget.maxZoom);
    }
    widget.onMapReady?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final interactive = widget.interactive;
    return ValueListenableBuilder<EdgeInsets?>(
      valueListenable: _controller._insets,
      builder: (context, insets, _) => gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(
        target: _g(widget.initialCenter),
        zoom: widget.initialZoom,
      ),
      onMapCreated: _onCreated,
      markers: _markers(),
      polylines: _polylines(ratio),
      circles: _circles(ratio),
      padding: insets ?? widget.padding,
      minMaxZoomPreference: gm.MinMaxZoomPreference(null, widget.maxZoom),
      scrollGesturesEnabled: interactive,
      zoomGesturesEnabled: interactive,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      buildingsEnabled: false,
      onCameraMove: (pos) {
        _center = _l(pos.target);
        _zoom = pos.zoom;
        _controller._center = _center;
        _controller._zoom = _zoom;
        widget.onCameraMove?.call(_center, _zoom, !_controller._programmatic);
      },
      onCameraIdle: () {
        final byUser = !_controller._programmatic;
        _controller._programmatic = false;
        widget.onCameraIdle?.call(_center, _zoom, byUser);
      },
      ),
    );
  }
}
