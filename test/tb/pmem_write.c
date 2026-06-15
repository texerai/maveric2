#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#define PMEM_WRITE_FILE_ENV "MAVERIC_PMEM_WRITE_FILE"

static FILE *pmem_write_file = NULL;
static int pmem_write_file_failed = 0;

static void close_pmem_write_file(void) {
    if (pmem_write_file != NULL) {
        fclose(pmem_write_file);
        pmem_write_file = NULL;
    }
}

static FILE *get_pmem_write_file(void) {
    const char *pmem_write_file_path;

    if (pmem_write_file != NULL) {
        return pmem_write_file;
    }

    pmem_write_file_path = getenv(PMEM_WRITE_FILE_ENV);
    if (pmem_write_file_path == NULL || pmem_write_file_path[0] == '\0') {
        return stdout;
    }

    if (pmem_write_file_failed) {
        return stdout;
    }

    pmem_write_file = fopen(pmem_write_file_path, "ab");
    if (pmem_write_file == NULL) {
        perror(pmem_write_file_path);
        pmem_write_file_failed = 1;
        return stdout;
    }

    atexit(close_pmem_write_file);
    return pmem_write_file;
}

void pmem_write(uint64_t waddr, uint64_t wdata, uint8_t wmask) {
    (void)waddr;
    (void)wmask;

    FILE *out = get_pmem_write_file();

    fputc((int)(wdata & 0xff), out);
    fflush(out);
}
