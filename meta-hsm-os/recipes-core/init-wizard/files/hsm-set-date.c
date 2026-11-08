// SPDX-License-Identifier: MIT
/*
 * hsm-set-date.c - Air-gapped system and hardware RTC clock configuration helper
 *
 * Allows unprivileged operator to adjust UTC system time on air-gapped
 * systems and synchronizes with hardware RTC (/dev/rtc0) when present without sudo.
 */
#define _GNU_SOURCE
#define _DEFAULT_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

#ifdef __linux__
#include <linux/rtc.h>
#include <sys/ioctl.h>
#else
#include <sys/ioctl.h>
struct rtc_time {
    int tm_sec;
    int tm_min;
    int tm_hour;
    int tm_mday;
    int tm_mon;
    int tm_year;
    int tm_wday;
    int tm_yday;
    int tm_isdst;
};
#ifndef RTC_SET_TIME
#define RTC_SET_TIME 0x4024700a
#endif
#endif

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
    if (utc_now != NULL) {
        strftime(out_buf, sizeof(out_buf), "%Y-%m-%d %H:%M:%S UTC", utc_now);
        printf("System clock successfully updated to: %s\n", out_buf);
    }

    /* Synchronize hardware Real-Time Clock (/dev/rtc0) if present */
    if (access("/dev/rtc0", F_OK) == 0) {
        int rtc_fd = open("/dev/rtc0", O_RDWR);
        if (rtc_fd < 0) {
            fprintf(stderr, "Warning: Unable to open /dev/rtc0: %s\n", strerror(errno));
        } else {
            struct rtc_time rtc_tm;
            memset(&rtc_tm, 0, sizeof(rtc_tm));
            if (utc_now != NULL) {
                rtc_tm.tm_sec   = utc_now->tm_sec;
                rtc_tm.tm_min   = utc_now->tm_min;
                rtc_tm.tm_hour  = utc_now->tm_hour;
                rtc_tm.tm_mday  = utc_now->tm_mday;
                rtc_tm.tm_mon   = utc_now->tm_mon;
                rtc_tm.tm_year  = utc_now->tm_year;
                rtc_tm.tm_wday  = utc_now->tm_wday;
                rtc_tm.tm_yday  = utc_now->tm_yday;
                rtc_tm.tm_isdst = utc_now->tm_isdst;
            }

            if (ioctl(rtc_fd, RTC_SET_TIME, &rtc_tm) < 0) {
                fprintf(stderr, "Warning: Failed to set RTC time via ioctl(RTC_SET_TIME): %s\n", strerror(errno));
            } else {
                printf("Hardware RTC (/dev/rtc0) synchronized successfully.\n");
            }
            close(rtc_fd);
        }
    } else {
        printf("Hardware RTC (/dev/rtc0) not present; skipped hardware clock synchronization.\n");
    }

    return 0;
}
