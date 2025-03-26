import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../data/db.dart';
import 'options_card.dart';

class OpenStreetMapSearchAndPick extends StatefulWidget {
  final IconData currentLocationIcon;
  final IconData resetIcon;
  final IconData locationPinIcon;
  final Color buttonTextColor;
  final Color locationPinIconColor;
  final String locationPinText;
  final TextStyle locationPinTextStyle;
  final String baseUri;

  const OpenStreetMapSearchAndPick({
    super.key,
    this.currentLocationIcon = Icons.my_location,
    this.resetIcon = Icons.near_me,
    this.locationPinIconColor = Colors.blue,
    this.locationPinText = 'Location',
    this.locationPinTextStyle = const TextStyle(
        fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
    this.buttonTextColor = Colors.black38,
    this.baseUri = 'https://nominatim.openstreetmap.org',
    this.locationPinIcon = Icons.location_on,
  });

  @override
  State<OpenStreetMapSearchAndPick> createState() =>
      _OpenStreetMapSearchAndPickState();
}

class _OpenStreetMapSearchAndPickState
    extends State<OpenStreetMapSearchAndPick> {
  static const _useTransformerId = 'useTransformerId';

  var reCenter = false;
  bool _isLoading = false;
  bool _isSearching = false;

  bool _canSearch = true;

  MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  var client = http.Client();
  late Future<Position?> latlongFuture;

  late List<dynamic> stolpersteins = [];
  List<dynamic> _options = [];

  Future<Position?> getCurrentPosLatLong() async {
    LocationPermission locationPermission = await Geolocator.checkPermission();

    /// do not have location permission
    if (locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
      return await getPosition(locationPermission);
    }

    /// have location permission
    Position position = await Geolocator.getCurrentPosition();
    //setNameCurrentPosAtInit(position.latitude, position.longitude);
    return position;
  }

  Future<Position?> getPosition(LocationPermission locationPermission) async {
    if (locationPermission == LocationPermission.denied ||
        locationPermission == LocationPermission.deniedForever) {
      return null;
    }
    Position position = await Geolocator.getCurrentPosition();
    //setNameCurrentPosAtInit(position.latitude, position.longitude);
    return position;
  }

/*
  void setNameCurrentPos() async {
    double latitude = _mapController.camera.center.latitude;
    double longitude = _mapController.camera.center.longitude;
    if (kDebugMode) {
      print("$latitude, $longitude");
    }
    String url =
        '${widget.baseUri}/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1';

    var response = await client.get(Uri.parse(url));
    // var response = await client.post(Uri.parse(url));
    var decodedResponse =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<dynamic, dynamic>;
/*
    _searchController.text =
        decodedResponse['display_name'] ?? "MOVE TO CURRENT POSITION";
*/
    setState(() {});
  }
*/

/*   void setNameCurrentPosAtInit(double latitude, double longitude) async {
    if (kDebugMode) {
      print("$latitude, $longitude");
    }

    String url =
        '${widget.baseUri}/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1';

    var response = await client.get(Uri.parse(url));
    // var response = await client.post(Uri.parse(url));
    var decodedResponse =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<dynamic, dynamic>;
/*
    _searchController.text =
        decodedResponse['display_name'] ?? "MOVE TO CURRENT POSITION";
*/
  } */

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _mapController.mapEventStream.listen(
      (event) async {
        if ((!_canSearch && _mapController.camera.zoom >= 9) ||
            (_canSearch && _mapController.camera.zoom < 9)) {
          setState(() {
            _canSearch = _mapController.camera.zoom >= 9;
          });
        }
        if (reCenter) {
          reCenter = false;
          print("Trovati: ${stolpersteins.length}");
          setState(() {});
        }

//        }
      },
    );
    latlongFuture = getCurrentPosLatLong();

    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Color.fromRGBO(0, 0, 0, 0),
      ),
    );
    // String? _autocompleteSelection;
/*     OutlineInputBorder inputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white),
    ); */
/*     OutlineInputBorder inputFocusBorder = OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white, width: 3.0),
    ); */
    return FutureBuilder<Position?>(
      future: latlongFuture,
      builder: (context, snapshot) {
        LatLng? mapCentre;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text("Something went wrong"),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          mapCentre = LatLng(snapshot.data!.latitude, snapshot.data!.longitude);
        }
        return Stack(
          children: [
            Positioned.fill(
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: FlutterMap(
                  options: MapOptions(
                      initialCenter: mapCentre!,
                      initialZoom: 15.0,
                      maxZoom: 18,
                      minZoom: 6),
                  mapController: _mapController,
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      userAgentPackageName: 'it.luigimicco.stolperstein',
                      tileUpdateTransformer: _animatedMoveTileUpdateTransformer,
                      tileProvider: CancellableNetworkTileProvider(),
                    ),
                    MarkerLayer(
                      markers: [
                        for (var stolperstein in stolpersteins)
                          Marker(
                            point: LatLng(stolperstein[1], stolperstein[2]),
                            width: 80,
                            height: 80,
                            child: InkWell(
                              onTap: () async {
                                setState(() {
                                  _isLoading = true;
                                });
                                var response = await Dio().get(
                                    'https://overpass-api.de/api/interpreter?data=[out:json][timeout:25];node(id:${stolperstein[0]});out;');
                                List<dynamic> items = json
                                    .decode(response.toString())['elements'];

                                Map<String, dynamic> tags = items[0]['tags'];
                                if (tags.containsKey("memorial:name")) {
                                  tags.remove("memorial:name");
                                }
                                if (tags.containsKey("name")) {
                                  tags.remove("name");
                                }
                                if (tags.containsKey("memorial")) {
                                  tags.remove("memorial");
                                }
                                if (tags.containsKey("historic")) {
                                  tags.remove("historic");
                                }
                                if (tags.containsKey("network")) {
                                  tags.remove("network");
                                }

                                if (tags.containsKey("image") &&
                                    tags['image']
                                        .toString()
                                        .startsWith("File:")) {
                                  tags.remove("image");
                                }

                                List<Widget> rows = [];
                                tags.forEach((k, v) {
                                  return rows.add(OptionCard(
                                    label: k,
                                    caption: v,
                                  ));
                                });
                                setState(() {
                                  _isLoading = false;
                                });
                                showDialog(
                                  // ignore: use_build_context_synchronously
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text(stolperstein[3]),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            for (var tag in rows) tag,
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          child: Text("Close"),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        )
                                      ],
                                    );
                                  },
                                );
                              },
                              child: Icon(
                                shadows: [
                                  Shadow(
                                    color: Color.fromRGBO(0, 0, 0, 0.5),
                                    offset: Offset(2, 2),
                                    blurRadius: 1,
                                  ),
                                ],
                                Icons.location_pin,
                                color: Colors.blue,
                                size: 48,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              bottom: true,
              child: Stack(children: [
                Visibility(
                  visible: false,
                  replacement: Container(),
                  child: Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(widget.locationPinText,
                                style: widget.locationPinTextStyle,
                                textAlign: TextAlign.center),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 50),
                              child: Icon(
                                shadows: [
                                  Shadow(
                                    color: Color.fromRGBO(0, 0, 0, 0.5),
                                    offset: Offset(2, 2),
                                    blurRadius: 1,
                                  ),
                                ],
                                Icons.location_pin,
                                color: Colors.red,
                                size: 48,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isLoading)
                  Positioned(
                      bottom: 0,
                      left: 0,
                      top: 0,
                      right: 0,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      )),
                Positioned(
                  top: 15,
                  right: 5,
                  child: FloatingActionButton(
                    mini: true,
                    heroTag: 'recenter',
                    backgroundColor: Colors.white,
                    onPressed: () async {
                      reCenter = true;
                      if (mapCentre != null) {
                        _mapController.move(
                            LatLng(mapCentre.latitude, mapCentre.longitude),
                            _mapController.camera.zoom);
                      } else {
                        _mapController.move(
                            LatLng(50.5, 30.51), _mapController.camera.zoom);
                      }
                      //setNameCurrentPos();
                    },
                    child: Icon(
                      widget.currentLocationIcon,
                      color: widget.buttonTextColor,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 5,
                  child: FloatingActionButton(
                    mini: true,
                    heroTag: 'reset',
                    backgroundColor: Colors.white,
                    onPressed: () async {
                      reCenter = true;
                      _mapController.rotate(0);
                      //setNameCurrentPos();
                    },
                    child: Icon(
                      widget.resetIcon,
                      color: widget.buttonTextColor,
                    ),
                  ),
                ),
                Positioned(
                  top: 15,
                  left: 5,
                  child: FloatingActionButton(
                    mini: true,
                    heroTag: 'info',
                    backgroundColor: Colors.white,
                    onPressed: () => showDialog<String>(
                      context: context,
                      builder: (BuildContext context) => Dialog(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'Stolpersteine v. 1.0.0',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                'Questa applicazione permette di evidenziare su una mappa la posizione delle Pietre di Inciampo ' +
                                    'memorizzate come punti di interesse nel database di Open Street Map',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal),
                              ),
                              const SizedBox(height: 15),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    child: Icon(
                      Icons.question_mark,
                      color: widget.buttonTextColor,
                    ),
                  ),
                ),
                Positioned(
                  top: 15,
                  left: 55,
                  right: 55,
                  child: Container(
                    //margin: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.5),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: Offset(0, 3), // changes position of shadow
                          ),
                        ]),
                    child: Column(
                      children: [
                        TextFormField(
                          maxLines: 1,
                          controller: _searchController,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.only(right: 16),
                            filled: false,
                            isDense: true,
                            hintText: 'search by name ...',
                            prefixIcon: _isSearching
                                ? SizedBox(
                                    height: 6,
                                    width: 6,
                                    child: Center(
                                        child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    )))
                                : Icon(Icons.search, size: 22),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (String value) {
                            if (_debounce?.isActive ?? false) {
                              _debounce?.cancel();
                            }
                            setState(() {
                              _isSearching = (value.length > 3);
                            });
                            if (value.length > 3) {
                              _debounce = Timer(
                                  const Duration(milliseconds: 1000), () async {
                                value = value.toLowerCase();
                                List<dynamic> res = db.where((item) {
                                  return item[3]
                                      .toString()
                                      .toLowerCase()
                                      .contains(value);
                                }).toList();

                                setState(() {
                                  _options = res;
                                  _isSearching = false;
                                });
                              });
                            } else {
                              setState(() {
                                _options = [];
                                _isSearching = false;
                              });
                            }
                          },
                        ),
                        StatefulBuilder(
                          builder: ((context, setState) {
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                                  _options.length > 5 ? 5 : _options.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  dense: true,
                                  title: Text(_options[index][3]),
                                  onTap: () {
                                    reCenter = true;
                                    setState(() {
                                      _searchController.text = "";
                                      stolpersteins.clear();
                                      stolpersteins.add(_options[index]);
                                    });
                                    _mapController.move(
                                        LatLng(_options[index][1],
                                            _options[index][2]),
                                        15.0);
                                    _focusNode.unfocus();
                                    _options.clear();
                                    //setState(() {});
                                  },
                                );
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_canSearch)
                  Positioned(
                    bottom: 0,
                    left: 30,
                    right: 30,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          style: ButtonStyle(
                              backgroundColor:
                                  WidgetStateProperty.all(Colors.white),
                              foregroundColor: WidgetStateProperty.all(
                                  Color.fromRGBO(0, 0, 0, .7))),
                          onPressed: () async {
                            setState(() {
                              _isLoading = true;
                            });

                            reCenter = false;

                            double minRay = min(
                                    _mapController.camera.visibleBounds.north -
                                        _mapController
                                            .camera.visibleBounds.south,
                                    _mapController.camera.visibleBounds.east -
                                        _mapController
                                            .camera.visibleBounds.west) /
                                2;
                            minRay = pow(minRay, 2) as double;

                            final res = db.where((item) {
                              double dy = (item[1] as double) -
                                  _mapController.camera.center.latitude;
                              double dx = (item[2] as double) -
                                  _mapController.camera.center.longitude;

                              return (pow(dx, 2) + pow(dy, 2)) <= minRay;
                            }).toList();
                            print("Trovati: ${res.length}");
                            setState(() {
                              stolpersteins = res;
                              _isLoading = false;
                            });
                          },
                          child: Text('Search here'),
                        ),
                      ),
                    ),
                  )
              ]),
            ),
          ],
        );
      },
    );
  }

/*   Future<PickedData> pickData() async {
    LatLong center = LatLong(_mapController.camera.center.latitude,
        _mapController.camera.center.longitude);
    var client = http.Client();
    String url =
        '${widget.baseUri}/reverse?format=json&lat=${_mapController.camera.center.latitude}&lon=${_mapController.camera.center.longitude}&zoom=18&addressdetails=1';

    var response = await client.get(Uri.parse(url));
    // var response = await client.post(Uri.parse(url));
    var decodedResponse =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<dynamic, dynamic>;
    String displayName = decodedResponse['display_name'];
    return PickedData(center, displayName, decodedResponse["address"]);
  } */

  /// Inspired by the contribution of [rorystephenson](https://github.com/fleaflet/flutter_map/pull/1475/files#diff-b663bf9f32e20dbe004bd1b58a53408aa4d0c28bcc29940156beb3f34e364556)
  final _animatedMoveTileUpdateTransformer = TileUpdateTransformer.fromHandlers(
    handleData: (updateEvent, sink) {
      final id = AnimationId.fromMapEvent(updateEvent.mapEvent);

      if (id == null) return sink.add(updateEvent);
      if (id.customId != _OpenStreetMapSearchAndPickState._useTransformerId) {
        if (id.moveId == AnimatedMoveId.started) {
          debugPrint(
              'TileUpdateTransformer disabled, using default behaviour.');
        }
        return sink.add(updateEvent);
      }

      switch (id.moveId) {
        case AnimatedMoveId.started:
          debugPrint('Loading tiles at animation destination.');
          sink.add(
            updateEvent.loadOnly(
              loadCenterOverride: id.destLocation,
              loadZoomOverride: id.destZoom,
            ),
          );
          break;
        case AnimatedMoveId.inProgress:
          // Do not prune or load during movement.
          break;
        case AnimatedMoveId.finished:
          debugPrint('Pruning tiles after animated movement.');
          sink.add(updateEvent.pruneOnly());
          break;
      }
    },
  );
}

class LatLong {
  final double latitude;
  final double longitude;
  const LatLong(this.latitude, this.longitude);
}

/* class PickedData {
  final LatLong latLong;
  final String addressName;
  final Map<String, dynamic> address;

  PickedData(this.latLong, this.addressName, this.address);
} */
