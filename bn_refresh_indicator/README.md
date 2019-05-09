# bn_refresh_indicator

A system based refresh & load component.

## Feature

- System based, no intrusion.
- Support automatic refresh, manual control refresh.
- Support no data display.

## How To Use It .

It's basically the same as the native RefreshIndicator.

```dart
BnRefreshIndicator(
          refreshController: refreshController, // Control refresh action
          autoRefresh: false,
          nodataWidget: Text('there is no data'),
          onRefresh: () async {
            await Future.delayed(Duration(seconds: 3));
            more = !more;
            _counter = 10;
            if (mounted) {
              setState(() {});
            }
            return more;
          },
          onLoadMore: () async {
            await Future.delayed(Duration(seconds: 3));
            _counter += 10;
            if (mounted) {
              setState(() {});
            }
            return false;
          },
          child: ListView.builder(
            // physics: BouncingScrollPhysics,
            itemBuilder: (context, index) {
              return GestureDetector(
                child: Card(
                  child: Center(
                    child: Text('index -- $index'),
                  ),
                ),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) {
                    return MyHomePage(title: 'Second page');
                  }));
                },
              );
            },
            itemCount: _counter,
            itemExtent: 88.0,
          ),
        )
```



## Reference

![refresh](<https://github.com/BackNotGod/BnRefreshIndicator/blob/master/bn_refresh_indicator/example/refregif_low.gif>)



## Extension

It's very low intrusive, and if you don't need to load it just keep refresh, just Set `onLoadMore` to null or not assign it a value.

## Planned

Support for custom refresh animations.