#include <stdio.h>
#include <string.h>

extern int binary_search(int arr[], int size, int target);

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


int main(int argc, char *argv[]) {
    if(argc > 1) {
        // get arg of the testcase to run
        char *testcase = argv[1];
        
        if (strcmp(testcase, "binary_search") == 0 ){
            test_binary_search();
        } else {
            test_binary_search();
        }
    }
}
