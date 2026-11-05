// SPDX-License-Identifier: GPL-2.0-only
/*
 * nrf52840_hsm.c - Linux Kernel Driver for nRF52840 HSM USB Dongle
 *
 * Exposes deterministic device nodes: /dev/tty.hsm<ble_address><port>
 * In production mode (hsm_dev_mode=0), strictly binds to the HSM AT command
 * channel (cdc_acm_uart1) and suppresses the Zephyr debug logging interface.
 *
 * Copyright (C) 2026 Guillaume Pfister. All rights reserved.
 */

#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/usb.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/slab.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/mutex.h>
#include <linux/poll.h>
#include <linux/version.h>

#define DRIVER_NAME "nrf52840_hsm"
#define HSM_MAX_DEVICES 16
#define BUFFER_SIZE 4096

/* USB Vendor ID & Product ID */
#define NRF52840_HSM_VID 0x1209
#define NRF52840_HSM_PID 0x0001

static int hsm_dev_mode = 0;
module_param(hsm_dev_mode, int, 0644);
MODULE_PARM_DESC(hsm_dev_mode, "Enable developer mode: 1 = expose both console and AT ports, 0 = expose AT port only");

static struct usb_device_id hsm_table[] = {
    { USB_DEVICE_INTERFACE_CLASS(NRF52840_HSM_VID, NRF52840_HSM_PID, USB_CLASS_COMM) },
    { USB_DEVICE_INTERFACE_CLASS(NRF52840_HSM_VID, NRF52840_HSM_PID, USB_CLASS_CDC_DATA) },
    { USB_DEVICE(NRF52840_HSM_VID, NRF52840_HSM_PID) },
    { }
};
MODULE_DEVICE_TABLE(usb, hsm_table);

static dev_t hsm_major_dev;
static struct class *hsm_class;

struct hsm_port {
    struct usb_device *udev;
    struct usb_interface *interface;
    dev_t devno;
    struct cdev cdev;
    struct device *vdev;
    struct mutex lock;
    __u8 bulk_in_endpointAddr;
    __u8 bulk_out_endpointAddr;
    char ble_address[32];
    int port_index;
    bool is_open;
};

static int hsm_open(struct inode *inode, struct file *file)
{
    struct hsm_port *port;
    port = container_of(inode->i_cdev, struct hsm_port, cdev);
    if (!port || !port->udev)
        return -ENODEV;

    mutex_lock(&port->lock);
    port->is_open = true;
    file->private_data = port;
    mutex_unlock(&port->lock);

    return 0;
}

static int hsm_release(struct inode *inode, struct file *file)
{
    struct hsm_port *port = file->private_data;
    if (port) {
        mutex_lock(&port->lock);
        port->is_open = false;
        mutex_unlock(&port->lock);
    }
    return 0;
}

static ssize_t hsm_read(struct file *file, char __user *user_buf, size_t count, loff_t *ppos)
{
    struct hsm_port *port = file->private_data;
    int retval;
    int bytes_read;
    char *buf;

    if (!port || !port->udev)
        return -ENODEV;

    if (count > BUFFER_SIZE)
        count = BUFFER_SIZE;

    buf = kmalloc(count, GFP_KERNEL);
    if (!buf)
        return -ENOMEM;

    mutex_lock(&port->lock);
    retval = usb_bulk_msg(port->udev,
                          usb_rcvbulkpipe(port->udev, port->bulk_in_endpointAddr),
                          buf, count, &bytes_read, 2000);
    mutex_unlock(&port->lock);

    if (retval) {
        kfree(buf);
        return (retval == -ETIMEDOUT) ? 0 : retval;
    }

    if (copy_to_user(user_buf, buf, bytes_read)) {
        kfree(buf);
        return -EFAULT;
    }

    kfree(buf);
    return bytes_read;
}

static ssize_t hsm_write(struct file *file, const char __user *user_buf, size_t count, loff_t *ppos)
{
    struct hsm_port *port = file->private_data;
    int retval;
    int bytes_written;
    char *buf;

    if (!port || !port->udev)
        return -ENODEV;

    if (count > BUFFER_SIZE)
        count = BUFFER_SIZE;

    buf = kmalloc(count, GFP_KERNEL);
    if (!buf)
        return -ENOMEM;

    if (copy_from_user(buf, user_buf, count)) {
        kfree(buf);
        return -EFAULT;
    }

    mutex_lock(&port->lock);
    retval = usb_bulk_msg(port->udev,
                          usb_sndbulkpipe(port->udev, port->bulk_out_endpointAddr),
                          buf, count, &bytes_written, 2000);
    mutex_unlock(&port->lock);

    kfree(buf);

    if (retval)
        return retval;

    return bytes_written;
}

static const struct file_operations hsm_fops = {
    .owner   = THIS_MODULE,
    .open    = hsm_open,
    .release = hsm_release,
    .read    = hsm_read,
    .write   = hsm_write,
#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 12, 0)
    .llseek  = noop_llseek,
#endif
    /* Linux 6.12+: no_llseek was removed; a NULL .llseek makes the node non-seekable */
};

static int hsm_probe(struct usb_interface *interface, const struct usb_device_id *id)
{
    struct usb_device *udev = interface_to_usbdev(interface);
    struct usb_host_interface *iface_desc = interface->cur_altsetting;
    struct usb_endpoint_descriptor *endpoint;
    struct hsm_port *port;
    int i, iface_num, port_idx;
    int retval = -ENODEV;
    char dev_name[64];

    iface_num = iface_desc->desc.bInterfaceNumber;

    /*
     * Production Filtering Logic:
     * Interface 0 / 1 corresponds to CDC-ACM UART0 (Zephyr console/logger).
     * Interface 2 / 3 corresponds to CDC-ACM UART1 (HSM AT crypto interface).
     *
     * In production (hsm_dev_mode == 0), ignore the console interface completely.
     */
    if (!hsm_dev_mode && (iface_num == 0 || iface_num == 1)) {
        dev_info(&interface->dev, "nRF52840 HSM: Interface %d (debug console) suppressed in production mode.\n", iface_num);
        return -ENODEV;
    }

    /* Assign logical port index */
    port_idx = (!hsm_dev_mode) ? 0 : (iface_num >= 2 ? 1 : 0);

    port = kzalloc(sizeof(struct hsm_port), GFP_KERNEL);
    if (!port)
        return -ENOMEM;

    mutex_init(&port->lock);
    port->udev = usb_get_dev(udev);
    port->interface = interface;
    port->port_index = port_idx;

    /* Extract hardware BLE MAC serial string */
    if (udev->serial) {
        strscpy(port->ble_address, udev->serial, sizeof(port->ble_address));
    } else {
        snprintf(port->ble_address, sizeof(port->ble_address), "DEFAULT");
    }

    /* Find bulk endpoints */
    for (i = 0; i < iface_desc->desc.bNumEndpoints; ++i) {
        endpoint = &iface_desc->endpoint[i].desc;
        if (!port->bulk_in_endpointAddr && usb_endpoint_is_bulk_in(endpoint))
            port->bulk_in_endpointAddr = endpoint->bEndpointAddress;
        if (!port->bulk_out_endpointAddr && usb_endpoint_is_bulk_out(endpoint))
            port->bulk_out_endpointAddr = endpoint->bEndpointAddress;
    }

    if (!port->bulk_in_endpointAddr || !port->bulk_out_endpointAddr) {
        /* CDC-ACM data interface may be separate; keep going or fail gracefully */
        dev_dbg(&interface->dev, "Endpoints not yet ready or control interface %d\n", iface_num);
        retval = -ENODEV;
        goto error;
    }

    port->devno = MKDEV(MAJOR(hsm_major_dev), MINOR(hsm_major_dev) + iface_num);
    cdev_init(&port->cdev, &hsm_fops);
    port->cdev.owner = THIS_MODULE;

    retval = cdev_add(&port->cdev, port->devno, 1);
    if (retval) {
        dev_err(&interface->dev, "Failed to register cdev for HSM port\n");
        goto error;
    }

    /* Create deterministic character device node: /dev/tty.hsm<ble_address><number> */
    snprintf(dev_name, sizeof(dev_name), "tty.hsm%s%d", port->ble_address, port->port_index);
    port->vdev = device_create(hsm_class, &interface->dev, port->devno, port, "%s", dev_name);
    if (IS_ERR(port->vdev)) {
        retval = PTR_ERR(port->vdev);
        cdev_del(&port->cdev);
        goto error;
    }

    usb_set_intfdata(interface, port);
    dev_info(&interface->dev, "nRF52840 HSM: Registered /dev/%s for BLE %s (iface %d)\n",
             dev_name, port->ble_address, iface_num);

    return 0;

error:
    usb_put_dev(port->udev);
    kfree(port);
    return retval;
}

static void hsm_disconnect(struct usb_interface *interface)
{
    struct hsm_port *port = usb_get_intfdata(interface);

    if (!port)
        return;

    usb_set_intfdata(interface, NULL);

    if (port->vdev)
        device_destroy(hsm_class, port->devno);

    cdev_del(&port->cdev);

    mutex_lock(&port->lock);
    usb_put_dev(port->udev);
    port->udev = NULL;
    mutex_unlock(&port->lock);

    kfree(port);
    dev_info(&interface->dev, "nRF52840 HSM device disconnected\n");
}

static struct usb_driver hsm_driver = {
    .name       = DRIVER_NAME,
    .probe      = hsm_probe,
    .disconnect = hsm_disconnect,
    .id_table   = hsm_table,
};

static int __init nrf52840_hsm_init(void)
{
    int result;

    result = alloc_chrdev_region(&hsm_major_dev, 0, HSM_MAX_DEVICES, DRIVER_NAME);
    if (result < 0) {
        pr_err("nrf52840_hsm: Failed to allocate major number\n");
        return result;
    }

    hsm_class = class_create(DRIVER_NAME);
    if (IS_ERR(hsm_class)) {
        unregister_chrdev_region(hsm_major_dev, HSM_MAX_DEVICES);
        return PTR_ERR(hsm_class);
    }

    result = usb_register(&hsm_driver);
    if (result) {
        class_destroy(hsm_class);
        unregister_chrdev_region(hsm_major_dev, HSM_MAX_DEVICES);
        pr_err("nrf52840_hsm: Failed to register USB driver (error %d)\n", result);
        return result;
    }

    pr_info("nrf52840_hsm: Driver loaded successfully (dev_mode=%d)\n", hsm_dev_mode);
    return 0;
}

static void __exit nrf52840_hsm_exit(void)
{
    usb_deregister(&hsm_driver);
    class_destroy(hsm_class);
    unregister_chrdev_region(hsm_major_dev, HSM_MAX_DEVICES);
    pr_info("nrf52840_hsm: Driver unloaded\n");
}

module_init(nrf52840_hsm_init);
module_exit(nrf52840_hsm_exit);

MODULE_AUTHOR("Guillaume Pfister <gpfister@users.noreply.github.com>");
MODULE_DESCRIPTION("Out-of-tree USB Serial Driver for nRF52840 HSM Dongle");
MODULE_LICENSE("GPL");
MODULE_VERSION("1.0.0");
