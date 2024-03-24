#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <stdlib.h>
#include <math.h>

struct node {
    struct node *left;
    struct node *right;
    int value;
} node_t;
extern int binary_search(int arr[], int size, int target);
extern int is_same_tree(struct node* p, struct node* q);


void test_binary_search() {
    printf("Testing Binary Search...\n");
    int ret = 0;
    int inputs[4][4] = {
        {1, 2, 3, 4},
        {5, 6, 7, 8},
        {9, 10, 11, 12},
        {13, 14, 15, 16}
    };
    int size = 4;
    int targets[4] = {1, 6, 12, 17};
    int expected_outputs[4] = {0, 1, 3, -1};

    for (int i = 0; i < 4; i++) {
        int result = binary_search(inputs[i], size, targets[i]);
        if (result != expected_outputs[i]) {
            printf("Test case %d failed: Expected output %d, but got %d\n", i + 1, expected_outputs[i], result);
        }
        else {
            printf("Test case %d Passed.\n", i + 1);
        }
    }
}

void tree_construction_rec(long* data, int depth, int index, struct node* parent) {
    if(depth != 0) {
        parent->left = malloc(sizeof(struct node));
        parent->right = malloc(sizeof(struct node));
        parent->left->value = data[index];
        parent->right->value = data[index+1];
        tree_construction_rec(data, depth - 1, index+2, parent->left);
        tree_construction_rec(data, depth - 1, index+(pow(2, depth)), parent->right);
        return;
    }
    return;
}

struct node* tree_construction(long* data, int num_layers) {
    struct node* parent = malloc(sizeof(struct node));
    parent->value = data[0];
    tree_construction_rec(data, num_layers - 1, 1, parent);
    return parent;
}


void test_is_same_tree() {

    //same tree
    long tree1a[] = {14,13,12,1};
    long tree1b[] = {14,13,12,1};
    struct node* t1 = tree_construction(tree1a, 2);
    struct node* t2 = tree_construction(tree1b, 2);
    int result = is_same_tree(t1, t2);
    int expected = 1;
    if (result != expected) {
        printf("Test case %d failed: Expected output %d, but got %d\n", 0, expected, result);
    }
    else {
        printf("Test case %d Passed.\n", 0);
    }

    //!same tree
    long tree2a[] = {14,11,12};
    long tree2b[] = {14,11,1};
    t1 = tree_construction(tree2a, 2);
    t2 = tree_construction(tree2b, 2);
    result = is_same_tree(t1, t2);
    expected = 0;
    if (result != expected) {
        printf("Test case %d failed: Expected output %d, but got %d\n", 1, expected, result);
    }
    else {
        printf("Test case %d Passed.\n", 1);
    }

    //one null other not null
    long tree3b[] = {14,11,1};
    t2 = tree_construction(tree3b, 2);
    result = is_same_tree(NULL, t2);
    expected = 0;
    if (result != expected) {
        printf("Test case %d failed: Expected output %d, but got %d\n", 2, expected, result);
    }
    else {
        printf("Test case %d Passed.\n", 2);
    }

    //both null
    result = is_same_tree(NULL, NULL);
    expected = 1;
    if (result != expected) {
        printf("Test case %d failed: Expected output %d, but got %d\n", 3, expected, result);
    }
    else {
        printf("Test case %d Passed.\n", 3);
    }

    //!same tree pt2 one has less node
    long tree5a[] = {14,11,12};
    long tree5b[] = {14,11};
    t1 = tree_construction(tree5a, 2);
    t2 = tree_construction(tree5b, 2);
    result = is_same_tree(t1, t2);
    expected = 0;
    if (result != expected) {
        printf("Test case %d failed: Expected output %d, but got %d\n", 4, expected, result);
    }
    else {
        printf("Test case %d Passed.\n", 4);
    }
}


int main(int argc, char *argv[]) {
    if(argc > 1) {
        // get arg of the testcase to run
        char *testcase = argv[1];
        
        if (strcmp(testcase, "binary_search") == 0 ){
            test_binary_search();
        } else {
            test_is_same_tree();
        }
    }
}



