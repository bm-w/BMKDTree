//
//  BMKDTree.m
//  BMKDTree
//
//  Created by Bastiaan Marinus van de Weerd on 3/22/13.
//

#import "BMKDTree.h"


typedef struct BMKDTreeNode BMKDTreeNode;
struct BMKDTreeNode {
    __unsafe_unretained id datum;
    struct BMKDTreeNode *left, *right;
};

typedef struct BMKDTreeResult BMKDTreeResult;
struct BMKDTreeResult {
    BMKDTreeNode *node;
    union {double score; BMKDTreeChildType type;};
};

@interface BMKDTree ()
@property (nonatomic, readwrite, assign) BMKDTreeNode *rootNode;
@property (nonatomic, readwrite, retain) NSMutableArray *store;
@property (nonatomic, readwrite, copy) BMKDTreeComparator comparator;
- (instancetype)initWithObjects:(const id [])objects count:(NSUInteger)count comparator:(BMKDTreeComparator)comparator;
- (instancetype)initWithSet:(NSSet *)set comparator:(BMKDTreeComparator)comparator;
- (instancetype)initWithArray:(NSArray *)array comparator:(BMKDTreeComparator)comparator;
- (void)_build;
@end


void BMKDTreeCreate(__unsafe_unretained id *data, NSUInteger count, NSUInteger depth, BMKDTreeComparator comparator, void (^callback)(BMKDTreeNode *node));
BMKDTreeNode *BMKDTreeCreateSync(__unsafe_unretained id *data, NSUInteger count, NSUInteger depth, BMKDTreeComparator comparator);
void BMKDTreeRelease(BMKDTreeNode *node);
BMKDTreeResult BMKDTreeFind(BMKDTreeNode *node, NSUInteger depth, BMKDTreeNode target, BMKDTreeComparator comparator);
BMKDTreeResult BMKDTreeSearchNearest(BMKDTreeNode *node, NSUInteger depth, BMKDTreeNode target, BMKDTreeComparator comparator, BMKDTreeScorer scorer);
BMKDTreeNode *BMKDTreeInsert(BMKDTreeNode *node, NSUInteger depth, BMKDTreeNode target, BMKDTreeComparator comparator);
void BMKDTreeTraverse(BMKDTreeNode *node, NSUInteger depth, BMKDTreeChildType type, BMKDTreeTraverser traverser);


#pragma mark - Object wrapper implementation

@implementation BMKDTree {
    BMKDTreeNode *_rootNode;
    NSMutableArray *_store;
    BMKDTreeComparator _comparator;
}

@synthesize rootNode = _rootNode, store = _store, comparator = _comparator;

#pragma mark Life cycle

+ (BMKDTree *)treeWithSet:(NSSet *)set comparator:(BMKDTreeComparator)comparator {
    return [[self alloc] initWithSet:set comparator:comparator];
}

+ (BMKDTree *)treeWithArray:(NSArray *)array comparator:(BMKDTreeComparator)comparator {
    return [[self alloc] initWithArray:array comparator:comparator];
}

- (instancetype)_initWithArray:(NSMutableArray *)array comparator:(BMKDTreeComparator)comparator {
    if (!(self = [super init])) return nil;
	
    self.store = array;
    self.comparator = comparator;
    
    [self _build];
    
    return self;
}

- (instancetype)initWithObjects:(const id [])objects count:(NSUInteger)count comparator:(BMKDTreeComparator)comparator {
    return [self _initWithArray:[NSMutableArray arrayWithObjects:objects count:count] comparator:comparator];
}

- (instancetype)initWithArray:(NSArray *)array comparator:(BMKDTreeComparator)comparator {
    return [self _initWithArray:[array mutableCopy] comparator:comparator];
}

- (instancetype)initWithSet:(NSSet *)set comparator:(BMKDTreeComparator)comparator {
    return [self _initWithArray:[[set allObjects] mutableCopy] comparator:comparator];
}

- (void)dealloc {
    BMKDTreeRelease(self.rootNode), self.rootNode = NULL;
    self.comparator = nil;
    self.store = nil;
}

#pragma mark Wrapped methods

- (void)_build {
    NSUInteger count = [self.store count];
    __unsafe_unretained id *data = (__unsafe_unretained id *)malloc(count * sizeof(id));
    [self.store getObjects:data range:NSMakeRange(0, count)];
    self.rootNode = BMKDTreeCreateSync(data, count, 0, self.comparator);
    free(data);
}

- (void)insertObject:(id)object usingComparator:(BMKDTreeComparator)comparator {
    BMKDTreeNode target = (BMKDTreeNode){.datum = object, .left = NULL, .right =  NULL},
    *node = BMKDTreeInsert(self.rootNode, 0, target, comparator);
    [self.store addObject:node->datum];
}

- (void)insertObject:(id)object {
    [self insertObject:object usingComparator:self.comparator];
}

- (id)nearestObjectToObject:(id)object usingComparator:(BMKDTreeComparator)comparator scorer:(BMKDTreeScorer)scorer {
    BMKDTreeNode target = (BMKDTreeNode){.datum = object, .left = NULL, .right =  NULL};
    BMKDTreeResult result = BMKDTreeSearchNearest(self.rootNode, 0, target, comparator, scorer);
    return result.node->datum;
}

- (id)nearestObjectToObject:(id)object usingScorer:(BMKDTreeScorer)scorer {
    return [self nearestObjectToObject:object usingComparator:self.comparator scorer:scorer];
}

- (void)traverseUsingBlock:(BMKDTreeTraverser)block {
    BMKDTreeTraverse(self.rootNode, 0, BMKDTreeNoChild, block);
}

- (NSString *)describeUsingBlock:(BMKDTreeDescriber)block {
    NSMutableArray *components = [NSMutableArray arrayWithCapacity:[self.store count]];
    BMKDTreeTraverse(self.rootNode, 0, BMKDTreeNoChild, ^(NSUInteger depth, BMKDTreeChildType type, id obj, BOOL *stop) {
        NSString *prefix = [@"" stringByPaddingToLength:depth * 2 withString:@"  " startingAtIndex:0],
            *component = block(prefix, depth, type, obj, stop);
        if (component) [components addObject:component];
    });
    return [components componentsJoinedByString:@"\n"];
}

@end


#pragma mark - Algorithms implementation

//TODO: Fine-tune the magic numbers? (see #defines below)
NSUInteger _BMKDTreePartition(__unsafe_unretained id *data, NSUInteger count, NSUInteger depth, id pivot, BMKDTreeComparator comparator);
BMKDTreeNode *_BMKDTreeCreate(__unsafe_unretained id *data, NSUInteger count, NSUInteger depth, BMKDTreeComparator comparator, dispatch_group_t group);
BMKDTreeResult _BMKDTreeFind(BMKDTreeNode *node, NSUInteger depth, BMKDTreeNode target, BMKDTreeResult **results, NSUInteger *size, BMKDTreeComparator comparator);
BMKDTreeResult _BMKDTreeSearchNearest(BMKDTreeNode *node, NSUInteger depth, BMKDTreeNode target, BMKDTreeComparator comparator, double bestScore, BMKDTreeScorer scorer);

void BMKDTreeCreate(__unsafe_unretained id *data, NSUInteger count, NSUInteger depth, BMKDTreeComparator comparator, void (^callback)(BMKDTreeNode *node)) {
    dispatch_queue_t originQueue = dispatch_get_current_queue();
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BMKDTreeNode *root = BMKDTreeCreateSync(data, count, depth, comparator);
        dispatch_async(originQueue, ^{
            callback(root);
        });
    });
}

BMKDTreeNode *BMKDTreeCreateSync(__unsafe_unretained id *data, NSUInteger count, NSUInteger depth, BMKDTreeComparator comparator) {
    dispatch_group_t group = dispatch_group_create();
    BMKDTreeNode *root = _BMKDTreeCreate(data, count, depth, comparator, group);
    
    /// The `_BMKDTreeCreate` function returns early (to free up space on the queue); its leaves are asynchronously populated later on...
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    return root;
}

#define CREATE__SUBSET_SIZE 256
#define CREATE__CONCURRENT_SIZE 128
BMKDTreeNode *_BMKDTreeCreate(__unsafe_unretained id *data, NSUInteger count, NSUInteger depth, BMKDTreeComparator comparator, dispatch_group_t group) {
    id pivot;
    NSUInteger partitionCount, medianIndex;
    
    /// The partitioning strategy depends on the size of the data set. In all cases, a pivot is selected close to the median, after which the data is partitioned in smaller, or larger or equal (< or >=) than the pivot
    if (count > 1.5 * CREATE__SUBSET_SIZE) {
        /// For large data sets, approximate the median by selecting the median of a smaller ordered subset (this will result in a slightly unbalanced tree)
        NSUInteger subset[CREATE__SUBSET_SIZE];
        
        for (uint i = 0; i < CREATE__SUBSET_SIZE; ++i) subset[i] = random() % count;
        qsort_b(subset, CREATE__SUBSET_SIZE, sizeof(NSUInteger), ^int(const void *i1, const void *i2) {
            return (int)comparator(depth, data[*(NSUInteger *)i1], data[*(NSUInteger *)i2]);
        });
        
        pivot = data[subset[medianIndex = CREATE__SUBSET_SIZE / 2]], data[medianIndex] = data[count - 1];
        partitionCount = _BMKDTreePartition(data, count - 1, depth, pivot, comparator);
    } else if (count > 1) {
        /// For smaller data sets, select the actual median after sorting the data
        qsort_b(data, count, sizeof(id), ^int(const void *o1, const void *o2) {
            return (int)comparator(depth, *(__unsafe_unretained id *)o1, *(__unsafe_unretained id *)o2);
        });
        
        pivot = data[medianIndex = count / 2], data[medianIndex] = data[count - 1];
        partitionCount = medianIndex;
    } else {
        /// If there is only one datum, this is a leaf node...
        pivot = *data;
        partitionCount = 0;
    }
    
    __block BMKDTreeNode *ptr = malloc(sizeof(BMKDTreeNode));
    ptr->datum = pivot;
    
    void (^leftBlock)(void) = ^{
        ptr->left = partitionCount ? _BMKDTreeCreate(data, partitionCount, depth + 1, comparator, group) : NULL;
    };
    
    void (^rightBlock)(void) = ^{
        ptr->right = count - partitionCount - 1 ? _BMKDTreeCreate(&data[partitionCount], count - partitionCount - 1, depth + 1, comparator, group) : NULL;
    };
    
    if (group && count > CREATE__CONCURRENT_SIZE) {
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_group_async(group, queue, leftBlock);
        dispatch_group_async(group, queue, rightBlock);
    } else leftBlock(), rightBlock();
    
    return ptr;
}

void BMKDTreeRelease(BMKDTreeNode *node) {
    if (!node) return;
    BMKDTreeRelease(node->left);
    BMKDTreeRelease(node->right);
    free(node);
}

void BMKDTreeTraverse(BMKDTreeNode *node, NSUInteger depth, BMKDTreeChildType type, BMKDTreeTraverser traverser) {
    if (!node) return;
    BOOL shouldStop = NO;
    traverser(depth, BMKDTreeNoChild, node->datum, &shouldStop);
    if (shouldStop) return;
    
    BMKDTreeTraverse(node->left, depth + 1, BMKDTreeLeftChild, traverser);
    BMKDTreeTraverse(node->right, depth + 1, BMKDTreeRightChild, traverser);
}

BMKDTreeResult BMKDTreeFind(BMKDTreeNode *node, NSUInteger depth, BMKDTreeNode target, BMKDTreeComparator comparator) {
    return _BMKDTreeFind(node, depth, target, NULL, NULL, comparator);
}

#define FIND__INIT_SIZE 16
BMKDTreeResult _BMKDTreeFind(BMKDTreeNode *node, NSUInteger depth, BMKDTreeNode target, BMKDTreeResult **results, NSUInteger *size, BMKDTreeComparator comparator) {
    const NSUInteger S = sizeof(BMKDTreeResult), startingDepth = depth;
    NSUInteger _size = FIND__INIT_SIZE, offset;
    size = size ? size : &_size;
    BOOL shouldFree = results == NULL;
    BMKDTreeResult *_results = results ? *results : NULL;
    do {
        offset = depth - startingDepth;
        _results = !_results || offset == *size ? realloc(_results, (*size <<= 1) * S) : _results;
        BMKDTreeChildType type = NSOrderedAscending == comparator(depth, node->datum, target.datum) ? BMKDTreeRightChild : BMKDTreeLeftChild;
        _results[offset] = (BMKDTreeResult){.node = node, .type = type};
        node = BMKDTreeLeftChild == type ? node->left : node->right;
    } while (++depth && node != NULL);
    
    BMKDTreeResult result = _results[offset];
    if (shouldFree) free(_results);
    else *size = offset + 1, *results = _results;//realloc(results, (*size = depth) * S);
    return result;
}

BMKDTreeNode *BMKDTreeInsert(BMKDTreeNode *node, NSUInteger depth, BMKDTreeNode target, BMKDTreeComparator comparator) {
    BMKDTreeResult parentResult = BMKDTreeFind(node, depth, target, comparator);
    *(node = malloc(sizeof(BMKDTreeNode))) = target;
    return BMKDTreeRightChild == parentResult.type ? (parentResult.node->right = node) : (parentResult.node->left = node);
}

BMKDTreeResult BMKDTreeSearchNearest(BMKDTreeNode *node, NSUInteger depth, BMKDTreeNode target, BMKDTreeComparator comparator, BMKDTreeScorer scorer) {
    return _BMKDTreeSearchNearest(node, depth, target, comparator, DBL_MAX, scorer);
}

BMKDTreeResult _BMKDTreeSearchNearest(BMKDTreeNode *node, NSUInteger depth, BMKDTreeNode target, BMKDTreeComparator comparator, double bestScore, BMKDTreeScorer scorer) {
    const NSUInteger startingDepth = depth;
    NSUInteger size = FIND__INIT_SIZE;
    BMKDTreeResult *results = malloc(size * sizeof(BMKDTreeResult)), best = (BMKDTreeResult){.node = NULL, .score = NAN};
    _BMKDTreeFind(node, depth, target, &results, &size, comparator);
    
    BOOL stop = FALSE;
    for (NSUInteger i = size, offset; i > 0 && !stop; --i) {
        offset = i - 1, depth = startingDepth + offset;
        BMKDTreeResult *result = &results[offset];
        double score = result->score = scorer(depth, result->type, result->node->datum, target.datum, &stop);
        if (score < bestScore) best = *result, bestScore = score;
        
        //TODO: Semantically overloaded BMKDTreeNoChild... maybe find better semantics?
        if (bestScore > scorer(depth, BMKDTreeNoChild, result->node->datum, target.datum, &stop) &&
            NULL != (node = NSOrderedAscending == comparator(depth, result->node->datum, target.datum) ? result->node->left : result->node->right)) {
            *result = _BMKDTreeSearchNearest(node, depth + 1, target, comparator, bestScore, scorer);
            if (result->node) best = *result, bestScore = best.score;
        }
    }
    
    BMKDTreeResult result = best.node ? best : (BMKDTreeResult){.node = NULL, .score = NAN};
    free(results);
    return result;
}

#define PARTITION__CONCURRENT_SIZE 512
#define PARTITION__STRIDE 1024
NSUInteger _BMKDTreePartition(__unsafe_unretained id *data, NSUInteger count, NSUInteger depth, id pivot, BMKDTreeComparator comparator) {
    id swap = nil;
    NSUInteger i = 0, j = count;
    
    if (count > PARTITION__CONCURRENT_SIZE) {
        char *flags = (char *)malloc(count * sizeof(char)), _swap;
        dispatch_apply(count / PARTITION__STRIDE + 1, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t k) {
            for (NSUInteger i = k * PARTITION__STRIDE, n = MIN(i + PARTITION__STRIDE, count); i < n; ++i)
                flags[i] = (char)(NSOrderedAscending == comparator(depth, data[i], pivot));
        });
        
        while (i < j) {
            while (flags[i]) if (++i == j) return i;
            if (_swap = flags[i], swap = data[i++], i == j) return i - 1;
            
            do if (j-- == i) return j; while (!flags[j]);
            flags[i - 1] = flags[j], data[i - 1] = data[j], flags[j] = _swap, data[j] = swap;
        }
        
        free(flags);
    } else while (i < j) {
        while (comparator(depth, data[i], pivot) == NSOrderedAscending) if (++i == j) return i;
        if (swap = data[i++], i == j) return i - 1;
        
        do if (j-- == i) return j; while (comparator(depth, data[j], pivot) != NSOrderedAscending);
        data[i - 1] = data[j], data[j] = swap;
    }
    
    return i;
}