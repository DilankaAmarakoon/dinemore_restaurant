import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml_rpc/client_c.dart' as xml_rpc;

enum MediaType {
  image,
  video,
}

class TvViewModels {
  final String deviceId;
  final Uint8List imageByte;
  final double duration;
  final MediaType type;
  final Uri videoUrl;

  TvViewModels({
    required this.deviceId,
    required this.imageByte,
    required this.duration,
    required this.type,
    required this.videoUrl
  });
}

class TvViewModelsData{
  List <TvViewModels> imageDetailsDataList = [];

  Future<List<dynamic>> productLineData(
      String deviceIds,String urls,String dbNames,String passwords,int uIds, bool isUseOrNo
      )
  async {
    final  String url;
    final  int uId;
    final  String dbName;
    final  String password;
    final  String deviceId;

    if(isUseOrNo){
      url = "https://dinemorego-uat-22518241.dev.odoo.com";
      dbName = "dinemorego-uat-22518241";
      password = "123";
      // url = urls;
      // uId = uIds;
      // dbName = dbNames;
      // password = passwords;
      // deviceId = deviceIds;
    }else{
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      url = prefs.getString('url')!;
      uId = prefs.getInt('uId')!;
      dbName = prefs.getString('dbName')!;
      password = prefs.getString('password')!;
      deviceId = prefs.getString('deviceId')!;
    }
    // const url = 'https://skmjcdev-display-test.odoo.com/xmlrpc/2/object';
    // const db = 'skmjcdev-display-test-main-20654844';
    // const uid = 6;
    // const password = 'portal';

    try {
      final productData = await xml_rpc.call(Uri.parse("https://$url/xmlrpc/2/object"),
        'execute_kw',
        [dbName, 2, password, 'restaurant.display.line', 'search_read', [[['device_ip', '=', 34343434]]],],
      );
      print("eeccc.$productData");

      return productData;
    } catch (e) {
      return [];
    }
  }
  fetchProductLineDetails()async{
    imageDetailsDataList = [];
    List<dynamic> productData = await productLineData(
        "","","","",-1,false
    );
    for(dynamic item in productData){
      String? urlId;
      if(item["file_type"] == "video"){
        urlId = await convertVideoUrl(item["video"]);
      }
      try {
        final bytes = item["file_type"] == "image" ? base64Decode(item["image"]) : base64Decode("");
        imageDetailsDataList.add(TvViewModels(
            deviceId: item["device_ip"],
            imageByte: bytes,
            duration: item["duration"],
            type: item["file_type"] == "video" ? MediaType.video :MediaType.image,
            videoUrl: Uri.parse("https://drive.google.com/uc?export=download&id=$urlId")
        ));
      } catch (e) {
        print("Base64 decode failed: $e");
      }
    }
    print("ggh.${imageDetailsDataList.length}");
  }

  Future<String> convertVideoUrl (url) async {
    final regex = RegExp(r'd/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    } else {
      return 'Invalid link';
    }
  }
}
