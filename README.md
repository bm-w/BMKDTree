# BMKDTree

An Objective-C implementation of a k-D tree with arbitrary objects, by Bastiaan Marinus van de Weerd. Version 0.0.1.

## Usage

Initialize a tree using an array (or set) of objects and a comparator block:

~~~obj-c
#import "BMKDTree.h"

// ...

NSArray *array = // ...assumed to exist (array of `N`-dimensional datum objects)

BMKDTree *tree = [BMKDtree treeWithArray:array comparator:
^NSComparisonResult(NSUInteger depth, id datum1, id datum2) {
    const NSUInteger k = depth % N;
    const double difference = datum2.coordinates[k] - datum2.coordinates[k];
    return difference ? (difference > 0 ? NSOrderedAscending : NSOrderedDescending) : NSOrderedSame;
}];
~~~

Do a nearest-neighbour search using a scorer block:

~~~obj-c
BMKDTree *tree = // ...assumed to exist (e.g. same tree as above)
id originObject = // ...assumed to exist at coordindates {0, 0, ..., 0}

id nearestObject = [tree nearestObjectToObject:originObject usingScorer:
^double(NSUInteger depth, BMKDTreeChildType type, id datum, id target, BOOL *stop) {
    const double *xd = datum.coordinates, *xt = target.coordinates;
    double d0 = xd[0] - xt[0], d1 = xd[1] - xt[1], /* ... */, dn = xd[N - 1] - xt[N - 1];
    
    if (BMKDTreeNoChild == type) switch (depth %= N) {
    	// ...collapse to one-dimensional distance
    }
    
    return d0 * d0 + d1 * d1 + /* ... */ + dn * dn;
}];
~~~