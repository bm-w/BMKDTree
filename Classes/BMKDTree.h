//
//  BMKDTree.h
//  BMKDTree
//
//  Created by Bastiaan Marinus van de Weerd on 3/22/13.
//

#import <Foundation/Foundation.h>

typedef NSComparisonResult (^BMKDTreeComparator)(NSUInteger depth, id obj1, id obj2);

typedef enum {BMKDTreeNoChild = 0, BMKDTreeLeftChild, BMKDTreeRightChild} BMKDTreeChildType;
typedef void (^BMKDTreeTraverser)(NSUInteger depth, BMKDTreeChildType type, id obj, BOOL *stop);
typedef double (^BMKDTreeScorer)(NSUInteger depth, BMKDTreeChildType type, id obj, id target, BOOL *stop);
typedef NSString *(^BMKDTreeDescriber)(NSString *prefix, NSUInteger depth, BMKDTreeChildType type, id obj, BOOL *stop);

@interface BMKDTree : NSObject

+ (BMKDTree *)treeWithSet:(NSSet *)set comparator:(BMKDTreeComparator)comparator;
+ (BMKDTree *)treeWithArray:(NSArray *)array comparator:(BMKDTreeComparator)comparator;

- (void)insertObject:(id)object usingComparator:(BMKDTreeComparator)comparator;
- (void)insertObject:(id)object;

- (id)nearestObjectToObject:(id)object usingComparator:(BMKDTreeComparator)comparator scorer:(BMKDTreeScorer)scorer;
- (id)nearestObjectToObject:(id)object usingScorer:(BMKDTreeScorer)scorer;

- (void)traverseUsingBlock:(BMKDTreeTraverser)block;
- (NSString *)describeUsingBlock:(BMKDTreeDescriber)block;

@end
