import 'package:flutter/material.dart';
import 'Models/ad_model.dart';
import 'Models/ad_service2.dart';
import 'package:eduspark/ad_banner.dart';
import 'package:carousel_slider/carousel_slider.dart';

class AdCarousel extends StatefulWidget {
  final String placementLocation;
  final double height;
  final bool showDescription;

  const AdCarousel({
    Key? key,
    required this.placementLocation,
    this.height = 180,
    this.showDescription = false,
  }) : super(key: key);

  @override
  State<AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<AdCarousel> {
  final AdService _adService = AdService();
  List<AdModel> _ads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    setState(() {
      _isLoading = true;
    });

    final ads = await _adService.getAdsForPlacement(widget.placementLocation);

    setState(() {
      _ads = ads;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: widget.height,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_ads.isEmpty) {
      return SizedBox.shrink(); // Don't show anything if no ads
    }

    if (_ads.length == 1) {
      return AdBanner(
        ad: _ads.first,
        height: widget.height,
        showDescription: widget.showDescription,
      );
    }

    return Container(
      height: widget.height,
      child: CarouselSlider(
        options: CarouselOptions(
          height: widget.height,
          aspectRatio: 16/9,
          viewportFraction: 1.0,
          initialPage: 0,
          enableInfiniteScroll: _ads.length > 1,
          reverse: false,
          autoPlay: true,
          autoPlayInterval: Duration(seconds: 5),
          autoPlayAnimationDuration: Duration(milliseconds: 800),
          autoPlayCurve: Curves.fastOutSlowIn,
          enlargeCenterPage: false,
          scrollDirection: Axis.horizontal,
        ),
        items: _ads.map((ad) {
          return AdBanner(
            ad: ad,
            height: widget.height,
            showDescription: widget.showDescription,
          );
        }).toList(),
      ),
    );
  }
}