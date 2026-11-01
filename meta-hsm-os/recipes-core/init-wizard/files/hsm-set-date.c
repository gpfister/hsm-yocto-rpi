// SPDX-License-Identifier: MIT
/*
 * hsm-set-date.c - Air-gapped system clock configuration helper
 *
 * Allows unprivileged operator to adjust UTC system time on air-gapped
 * systems lacking battery-backed RTC and NTP connectivity without sudo.
 */
#define _GNU_SOURCE
#define _DEFAULT_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s \"YYYY-MM-DD HH:MM:SS\"\n", argv[0]);
        return 1;
    }

    struct tm tm_val;
    memset(&tm_val, 0, sizeof(struct tm));
    if (strptime(argv[1], "%Y-%m-%d %H:%M:%S", &tm_val) == NULL) {
        fprintf(stderr, "Error: Invalid date format '%s'. Expected 'YYYY-MM-DD HH:MM:SS'.\n", argv[1]);
        return 1;
    }

    time_t t = timegm(&tm_val);
    if (t == -1) {
        fprintf(stderr, "Error: Failed to convert time.\n");
        return 1;
    }

    struct timeval tv;
    tv.tv_sec = t;
    tv.tv_usec = 0;

    if (settimeofday(&tv, NULL) != 0) {
        perror("Error: Failed to set system clock (settimeofday)");
        return 1;
    }

    char out_buf[64];
    struct tm *utc_now = gmtime(&t);
    strftime(out_buf, sizeof(out_buf), "%Y-%m-%d %H:%M:%S UTC", utc_now);
    printf("System clock successfully updated to: %s\n", out_buf);
    return 0;
}
