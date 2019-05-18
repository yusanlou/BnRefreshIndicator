library bn_refresh_indicator;

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'dart:async';

enum _DragProgressMode {
  drag, // start.
  armed, // will loading
  snap, // can loading but can also be interrupted , Animating to the indicator's final "displacement".
  loading, // Running the refresh callback.
  done, // Animating the indicator's fade-out after refreshing.
  canceled, // Animating the indicator's fade-out after not arming.
}

typedef LoadMoreCallback = Future<dynamic> Function();

// The over-scroll distance that moves the indicator to its maximum
// displacement, as a percentage of the scrollable's container extent.
const double _kDragContainerExtentPercentage = 0.25;

// How much the scroll's drag gesture can overshoot the RefreshIndicator's
// displacement; max displacement = _kDragSizeFactorLimit * displacement.
const double _kDragSizeFactorLimit = 1.5;

// When the scroll ends, the duration of the refresh indicator's animation
// to the RefreshIndicator's displacement.
const Duration _kIndicatorSnapDuration = Duration(milliseconds: 150);

// The duration of the ScaleTransition that starts when the refresh action
// has completed.
const Duration _kIndicatorScaleDuration = Duration(milliseconds: 200);

class BnRefreshIndicator extends StatefulWidget {
  final LoadMoreCallback onRefresh;
  final Widget child;
  final Color backgroundColor;
  final LoadMoreCallback onLoadMore;
  final Widget nodataWidget;
  final bool autoRefresh;
  final BnRefreshController refreshController;
  BnRefreshIndicator(
      {@required this.child,
      @required this.onRefresh,
      this.refreshController,
      this.autoRefresh = false,
      this.onLoadMore,
      this.backgroundColor,
      this.nodataWidget});

  @override
  _BnRefreshIndicatorState createState() => _BnRefreshIndicatorState();
}

class _BnRefreshIndicatorState extends State<BnRefreshIndicator>
    with TickerProviderStateMixin<BnRefreshIndicator> {
  _DragProgressMode _mode;

  AnimationController _positionController;
  AnimationController _scaleController;
  Animation<double> _positionFactor;
  Animation<double> _scaleFactor;
  Animation<double> _value;
  Animation<Color> _valueColor;
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  double _dragOffset;
  bool isLoading = false;
  bool isRefreshing = false;
  bool hasMoreData = true;

  static final Animatable<double> _threeQuarterTween =
      Tween<double>(begin: 0.0, end: 0.75);
  static final Animatable<double> _kDragSizeFactorLimitTween =
      Tween<double>(begin: 0.0, end: _kDragSizeFactorLimit);
  static final Animatable<double> _oneToZeroTween =
      Tween<double>(begin: 1.0, end: 0.0);

  @override
  void initState() {
    super.initState();
    _positionController = AnimationController(vsync: this);
    _positionFactor = _positionController.drive(_kDragSizeFactorLimitTween);
    _value = _positionController.drive(
        _threeQuarterTween); // The "value" of the circular progress indicator during a drag.
    _scaleController = AnimationController(vsync: this);
    _scaleFactor = _scaleController.drive(_oneToZeroTween);

    if (widget.refreshController != null) {
      if (widget.autoRefresh || widget.refreshController.getRefreshEnable()) {
        // When called in the outer init method, it has not been initialized.
        startRefresh();
      }
      widget.refreshController.addListener(startRefresh);
    } else {
      if (widget.autoRefresh) {
        // When called in the outer init method, it has not been initialized.
        startRefresh();
      }
    }
  }

  @override
  void didChangeDependencies() {
    final ThemeData theme = Theme.of(context);
    _valueColor = _positionController.drive(
      ColorTween(
        begin: (theme.accentColor).withOpacity(0.0),
        end: (theme.accentColor).withOpacity(1.0),
      ).chain(
          CurveTween(curve: const Interval(0.0, 1.0 / _kDragSizeFactorLimit))),
    );
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _positionController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void startRefresh() {
    if (isRefreshing) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshKey?.currentState?.show();
    });
  }

  bool _start() {
    assert(_mode == null);

    _dragOffset = 0.0;
    _scaleController.value = 0.0;
    _positionController.value = 0.0;
    return true;
  }

  void _show() {
    assert(_mode != _DragProgressMode.loading);
    assert(_mode != _DragProgressMode.snap);
    final Completer<void> completer = Completer<void>();
    _mode = _DragProgressMode.snap;
    _positionController
        .animateTo(1.0 / _kDragSizeFactorLimit,
            duration: _kIndicatorSnapDuration)
        .then<void>((void value) {
      if (mounted && _mode == _DragProgressMode.snap) {
        assert(widget.onLoadMore != null);

        setState(() {
          // Show the indeterminate progress indicator.
          _mode = _DragProgressMode.loading;
        });

        final Future<dynamic> refreshResult = _checkLoadingActions();
        assert(() {
          if (refreshResult == null)
            FlutterError.reportError(FlutterErrorDetails(
              exception: FlutterError('The onLoadMore callback returned null.\n'
                  'The RefreshIndicator onLoadMore callback must return a Future.'),
              context: ErrorDescription('when calling onLoadMore'),
              library: 'bn_RefreshIndicator library',
            ));
          return true;
        }());
        if (refreshResult == null) return;
        refreshResult.whenComplete(() {}).then((hasMore) {
          if (mounted && _mode == _DragProgressMode.loading) {
            completer.complete();
            _dismiss(_DragProgressMode.done, hasMore is bool ? hasMore : true);
          }
        });
      }
    });
  }

  // Stop showing the refresh indicator.
  Future<void> _dismiss(_DragProgressMode newMode, bool hasMore) async {
    await Future<void>.value();
    // This can only be called from _show() when refreshing and
    // _handleScrollNotification in response to a ScrollEndNotification or
    // direction change.
    assert(newMode == _DragProgressMode.canceled ||
        newMode == _DragProgressMode.done);
    if (mounted) {
      setState(() {
        _mode = newMode;
      });
    }

    switch (_mode) {
      case _DragProgressMode.done:
        await _scaleController.animateTo(1.0,
            duration: _kIndicatorScaleDuration);
        break;
      case _DragProgressMode.canceled:
        await _scaleController.animateTo(1.0,
            duration: _kIndicatorScaleDuration);
        break;
      default:
        assert(false);
    }
    if (mounted && _mode == newMode) {
      _dragOffset = null;
      this.hasMoreData = hasMore;
      if (mounted) {
        setState(() {
          _mode = null;
        });
      }
    }
  }

  void _checkDragOffset(double containerExtent) {
    assert(_mode == _DragProgressMode.drag || _mode == _DragProgressMode.armed);
    double newValue =
        _dragOffset / (containerExtent * _kDragContainerExtentPercentage);
    if (_mode == _DragProgressMode.armed)
      newValue = math.max(newValue, 1.0 / _kDragSizeFactorLimit);
    _positionController.value =
        newValue.clamp(0.0, 1.0); // this triggers various rebuilds
    if (_mode == _DragProgressMode.drag && _valueColor.value.alpha == 0xFF)
      _mode = _DragProgressMode.armed;
  }

  bool _preHandleRefreshScrollNotification(ScrollNotification notification) =>
      !isLoading;

  bool _handleScrollNotification(ScrollNotification notification) {
    if (this.isRefreshing) {
      return false;
    }
    // pixels > maxScrollExtent
    if (notification is ScrollStartNotification &&
        notification.metrics.pixels >= notification.metrics.maxScrollExtent &&
        _mode == null &&
        _start()) {
      setState(() {
        _mode = _DragProgressMode.drag;
      });
      return false;
    } else if (notification is ScrollUpdateNotification) {
      if (_mode == _DragProgressMode.drag || _mode == _DragProgressMode.armed) {
        if (notification.metrics.extentBefore <=
            notification.metrics.maxScrollExtent) {
          _dismiss(_DragProgressMode.canceled, this.hasMoreData);
        } else {
          _dragOffset += notification.scrollDelta;
          _checkDragOffset(notification.metrics.viewportDimension);
        }
      }
      if (_mode == _DragProgressMode.armed &&
          notification.dragDetails == null) {
        // On iOS start the refresh when the Scrollable bounces back from the
        // overscroll (ScrollNotification indicating this don't have dragDetails
        // because the scroll activity is not directly triggered by a drag).
        _show();
      }
    } else if (notification is OverscrollNotification) {
      if (_mode == _DragProgressMode.drag || _mode == _DragProgressMode.armed) {
        _dragOffset += notification.overscroll / 2.0;
        _checkDragOffset(notification.metrics.viewportDimension);
      }
    } else if (notification is ScrollEndNotification) {
      switch (_mode) {
        case _DragProgressMode.armed:
          _show();
          break;
        case _DragProgressMode.drag:
          _dismiss(_DragProgressMode.canceled, this.hasMoreData);
          break;
        default:
          // do nothing
          break;
      }
    }
    return false;
  }

// begin loading hidden refresh
  Future _checkLoadingActions() async {
    isLoading = true;
    var hasMore = this.hasMoreData;
    if (this.hasMoreData) {
      final res = await widget.onLoadMore();
      if (res is bool) {
        hasMore = res;
      }
    }
    // set it to back
    isLoading = false;
    return hasMore;
  }

  Future _checkRefreshActions() async {
    this.hasMoreData = true;
    setState(() {});
    isRefreshing = true;
    final more = await widget.onRefresh();
    // set it to back
    isRefreshing = false;
    if (more == false) {
      this.hasMoreData = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Widget _getNodataDefalutWidget(double value) {
    if (value == 0) {
      return widget.nodataWidget == null
          ? Padding(
              padding: EdgeInsets.all(0),
            )
          : widget.nodataWidget;
    }
    return widget.nodataWidget;
  }

  @override
  Widget build(BuildContext context) {
    final bool showIndeterminateIndicator =
        _mode == _DragProgressMode.loading || _mode == _DragProgressMode.done;

    final Widget child = NotificationListener(
      child: RefreshIndicator(
        key: _refreshKey,
        notificationPredicate: _preHandleRefreshScrollNotification,
        onRefresh: _checkRefreshActions,
        child: widget.child,
      ),
      onNotification:
          widget.onLoadMore != null ? _handleScrollNotification : null,
    );
    return widget.onLoadMore == null
        ? child
        : Stack(
            children: <Widget>[
              child,
              Positioned(
                // top: 0.0,
                bottom: 0.0,
                left: 0.0,
                right: 0.0,
                child: SizeTransition(
                  axisAlignment: -1.0,
                  sizeFactor: _positionFactor, // this is what brings it down
                  child: Container(
                    padding: EdgeInsets.only(bottom: 40.0),
                    alignment: Alignment.bottomCenter,
                    child: ScaleTransition(
                      scale: _scaleFactor,
                      child: AnimatedBuilder(
                        animation: _positionController,
                        builder: (BuildContext context, Widget child) {
                          return this.hasMoreData
                              ? RefreshProgressIndicator(
                                  semanticsLabel:
                                      MaterialLocalizations.of(context)
                                          .refreshIndicatorSemanticLabel,
                                  semanticsValue: 'widget.semanticsValue',
                                  value: showIndeterminateIndicator
                                      ? null
                                      : _value.value,
                                  valueColor: _valueColor,
                                  backgroundColor: widget.backgroundColor,
                                )
                              : _getNodataDefalutWidget(_value.value);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
  }
}

class BnRefreshController extends ChangeNotifier {
  var _initializeRefreshEnable = false;
  void beginRefresh() {
    if (hasListeners) {
      notifyListeners();
    }
    _initializeRefreshEnable = true;
  }

  bool getRefreshEnable() {
    return _initializeRefreshEnable;
  }
}
