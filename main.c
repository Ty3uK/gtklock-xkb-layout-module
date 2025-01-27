#include <glib.h>
#include <string.h>
#include <stdio.h>

typedef char FixedString[16];

int main() {
    // Create a GArray to hold pointers to FixedString
    GArray *array = g_array_new(FALSE, FALSE, sizeof(FixedString*));

    // Add some elements to the array
    FixedString *str1 = malloc(sizeof(FixedString));
    strncpy(*str1, "Hello", 15);
    str1[0][15] = '\0';

    FixedString *str2 = malloc(sizeof(FixedString));
    strncpy(*str2, "World", 15);
    str2[0][15] = '\0';

    g_array_append_val(array, str1);
    g_array_append_val(array, str2);

    // Retrieve and print elements
    for (guint i = 0; i < array->len; i++) {
        FixedString **ptr = &g_array_index(array, FixedString*, i);
        printf("Element %u: %s\n", i, *ptr);
    }

    // Free the allocated memory
    for (guint i = 0; i < array->len; i++) {
        FixedString **ptr = &g_array_index(array, FixedString*, i);
        free(*ptr);
    }

    // Free the GArray itself
    g_array_free(array, TRUE);

    return 0;
}
