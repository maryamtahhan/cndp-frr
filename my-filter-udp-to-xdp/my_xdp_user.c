/* SPDX-License-Identifier: GPL-2.0 */

#include <assert.h>
#include <errno.h>
#include <getopt.h>
#include <locale.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <sys/resource.h>

#include <bpf/bpf.h>
#include <bpf/xsk.h>

#include <arpa/inet.h>
#include <net/if.h>
#include <linux/if_link.h>
#include <linux/if_ether.h>
#include <linux/ipv6.h>
#include <linux/icmpv6.h>


#include "../common/common_params.h"
#include "../common/common_user_bpf_xdp.h"
#include "../common/common_libbpf.h"


#define NUM_FRAMES         4096
#define FRAME_SIZE         XSK_UMEM__DEFAULT_FRAME_SIZE
#define RX_BATCH_SIZE      64
#define INVALID_UMEM_FRAME UINT64_MAX



static const char *__doc__ = "AF_XDP kernel bypass example\n";

static const struct option_wrapper long_options[] = {

    {{"help",    no_argument,       NULL, 'h' },
     "Show help", false},

    {{"dev",     required_argument, NULL, 'd' },
     "Operate on device <ifname>", "<ifname>", true},

    {{"skb-mode",    no_argument,       NULL, 'S' },
     "Install XDP program in SKB (AKA generic) mode"},

    {{"native-mode", no_argument,       NULL, 'N' },
     "Install XDP program in native mode"},

    {{"auto-mode",   no_argument,       NULL, 'A' },
     "Auto-detect SKB or native mode"},

    {{"unload",      no_argument,       NULL, 'U' },
     "Unload XDP program instead of loading"},

    {{"quiet",   no_argument,       NULL, 'q' },
     "Quiet mode (no output)"},

    {{"filename",    required_argument, NULL,  1  },
     "Load program from <file>", "<file>"},

    {{"progsec",     required_argument, NULL,  2  },
     "Load program in <section> of the ELF file", "<section>"},

    {{0, 0, NULL,  0 }, NULL, false}
};

static bool global_exit;

static void exit_application(int signal)
{
    signal = signal;
    global_exit = true;
}

int main(int argc, char **argv)
{
    struct config cfg = {
        .ifindex   = -1,
        .do_unload = false,
        .filename = "",
        .progsec = "xdp_packet_parser"
    };
    struct bpf_object *bpf_obj = NULL;

    /* Global shutdown handler */
    signal(SIGINT, exit_application);

    /* Cmdline options can change progsec */
    parse_cmdline_args(argc, argv, long_options, &cfg, __doc__);

    /* Required option */
    if (cfg.ifindex == -1) {
        fprintf(stderr, "ERROR: Required option --dev missing\n\n");
        usage(argv[0], __doc__, long_options, (argc == 1));
        return EXIT_FAIL_OPTION;
    }

    /* Unload XDP program if requested */
    if (cfg.do_unload)
        return xdp_link_detach(cfg.ifindex, cfg.xdp_flags, 0);

    /* Load custom program if configured */
    if (cfg.filename[0] != 0) {

        bpf_obj = load_bpf_and_xdp_attach(&cfg);
        if (!bpf_obj) {
            /* Error handling done in load_bpf_and_xdp_attach() */
            exit(EXIT_FAILURE);
        }
    }

    return EXIT_OK;
}
