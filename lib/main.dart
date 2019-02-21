import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as location_services;

void main() => runApp(MyApp());
FlutterBlue flutterBlue = FlutterBlue.instance;

BluetoothDevice device;
BluetoothCharacteristic characteristic;
BluetoothDescriptor move;
BluetoothDescriptor lights;


class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Board controller',
      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),
      home: MyHomePage(title: 'Board controller'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class TouchController extends StatefulWidget {
  static of(BuildContext context) =>
    context.inheritFromWidgetOfExactType(TouchController);
  @override
  _TouchControllerState createState() => _TouchControllerState();
}

class _TouchControllerState extends State<TouchController> {

  GoogleMapController mapController;

  @override
  Widget build(BuildContext context) {
    return new Stack(
      children: <Widget>[
        Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(48.8656626, 2.34522),
                zoom: 18.0,
              ),
              myLocationEnabled: true,
            ),
          ),
        ),
        Container(
          color: Colors.black54,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            new Text(
              device == null ? "Not connected" : "Connected",
            ),
            new Text(
              value.toString(),
              style: TextStyle(
                fontSize: 100,
                color: Colors.white,
              )
            ),
            new Text(
              valueSent.toString(),
              style: TextStyle(
                fontSize: 40,
                color: Colors.white,
              )
            ),
            new Text(
              "Battery: 0",
              style: TextStyle(
                fontSize: 40,
                color: Colors.white,
              )
            ),
            new Text(
              "RPM: 0",
              style: TextStyle(
                fontSize: 40,
                color: Colors.white,
              )
            ),
          ],
        ),
        GestureDetector(
          onTap: () => print('tapped!'),
          onVerticalDragDown: (DragDownDetails details) => _onVerticalDragDown(details),
          onVerticalDragUpdate: (DragUpdateDetails details) => _onVerticalDragUpdate(details),
          onVerticalDragEnd: (DragEndDetails details) => _onVerticalDragEnd(details),
          child: Container(
            color: Color.fromARGB(0, 0, 0, 0),
          )
        ),
      ]
    );
  }

  int base = 40;
  int value = 40;
  int valueSent = 40;

  Timer _debounce;

  // WARN: y for us
  double _currentY = 0;
  double _lastY = 0;

  Future<LatLng> _getStartingLocation() async {
    var location = location_services.Location();
    location_services.LocationData _currentLocation;
    _currentLocation = await location.getLocation();
    return LatLng(_currentLocation.latitude, _currentLocation.longitude);
  }

  /*_setCameraPos() async {
    var location = location_services.Location();
    location = await location.getLocation();
    mapController.moveCamera(new Camera)

  }*/

  _onVerticalDragDown(DragDownDetails details) {
    _lastY = details.globalPosition.dy;
    print("drag down " + _lastY.toString());
  }

  _onVerticalDragUpdate(DragUpdateDetails details) {
    _currentY = details.globalPosition.dy;
    int val = base + ((_lastY.toInt() - _currentY.toInt()) ~/ 14).toInt();
    if (value == val) return;

    setState(() {
      value = val;
    });
    print("drag update " + _currentY.toString() + " val: " + val.toString());
    _writeChar(value);
  }

  _onVerticalDragEnd(DragEndDetails details) {
    setState(() {
      value = base;
    });
    _writeChar(value);
    print("drag end");
  }

  _writeChar(int val) {
    if (_debounce?.isActive ?? false) _debounce.cancel();
    _debounce = Timer(const Duration(milliseconds: 14), () {
      print("write char: " + val.toString());
      setState(() {
        valueSent = val;
      });
      if (device != null) {
        device.writeDescriptor(move, [val]);
      }
    });
  }
}

class _MyHomePageState extends State<MyHomePage> {
  void _startScanning() {
    /// Start scanning
    print("start scanning");
    flutterBlue.scan().listen((scanResult) async {
      print(scanResult.device.name);
      if (scanResult.device.name != 'FBoard') return;

      print("device found");
      device = scanResult.device;
      flutterBlue.connect(device).listen((s) async {
        print("device connected");
        if (s == BluetoothDeviceState.connected) {
          List<BluetoothService> services = await device.discoverServices();
          print("got services");
          services.forEach((service) async {
            print("service: " + service.uuid.toString());
            if (service.uuid.toString() != '000000ff-0000-1000-8000-00805f9b34fb') return;

            print("found char");
            var characteristics = service.characteristics;
            characteristic = characteristics[0];
          });

          var descriptors = characteristic.descriptors;
          for(BluetoothDescriptor d in descriptors) {
            print("descriptor: " + d.uuid.toString());
            if (d.uuid.toString() == '00003333-0000-1000-8000-00805f9b34fb') move = d;
            if (d.uuid.toString() == '') lights = d;
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.map),
            onPressed: () {
            },
          ),
        ],
      ),
      body: TouchController(),
      floatingActionButton: FloatingActionButton(
        onPressed: _startScanning,
        tooltip: 'Start scan',
        child: Icon(Icons.bluetooth_searching),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
