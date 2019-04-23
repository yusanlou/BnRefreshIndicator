# bn_refresh_indicator

A system based refresh & load component.



## How To Use It .

It's basically the same as the native RefreshIndicator.

```dart
BnRefreshIndicator(
          onRefresh: () async {
            await Future.delayed(Duration(seconds: 1));
            _counter = 10;
            setState(() {});
            return;
          },
          onLoadMore: () async {
            await Future.delayed(Duration(seconds: 1));
            _counter += 10;
            setState(() {});
            return;
          },
          child: ListView.builder(
            itemBuilder: (context, index) {
              return Card(
                child: Center(
                  child: Text('index -- $index'),
                ),
              );
            },
            itemCount: _counter,
            itemExtent: 88.0,
          ),
        ) 
```



## Reference

![refresh](<https://github.com/BackNotGod/BnRefreshIndicator/blob/master/bn_refresh_indicator/example/test_bn_refreshindicator/refregif_low.gif>)



## Extension

It's very low intrusive, and if you don't need to load it just keep refresh, just Set `onLoadMore` to null or not assign it a value.

Welcome to support star if it can help.
