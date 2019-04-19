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

