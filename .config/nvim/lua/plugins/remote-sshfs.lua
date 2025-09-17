return {
  {
    "nosduco/remote-sshfs.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    opts = {
      connections = {
        ssh_configs = { -- which ssh configs to parse for hosts list
          vim.fn.expand("$HOME") .. "/.ssh/config",
        },
        sshfs_args = { -- arguments to pass to the sshfs command
          "-o", "reconnect",
          "-o", "ConnectTimeout=5",
          "-o", "ServerAliveInterval=15",
          "-o", "ServerAliveCountMax=3",
        },
      },
      mounts = {
        base_dir = vim.fn.expand("$HOME") .. "/.sshfs/", -- base directory for mount points
        unmount_on_exit = true, -- run sshfs as foreground, will unmount on vim exit
      },
      handlers = {
        on_connect = {
          change_dir = true, -- when connected change vim working directory to mount point
        },
        on_disconnect = {
          clean_mount_folders = false, -- remove mount point folder on disconnect/unmount
        },
      },
      ui = {
        select_prompts = false, -- not use nui/telescope but default vim.ui.select
        confirm = {
          connect = false, -- don't prompt for confirmation on connect
          change_dir = false, -- don't prompt for confirmation on change_dir
        },
      },
      log = {
        enable = true, -- enable logging
        truncate = false, -- truncate logs
        types = { -- enabled log types
          all = false,
          util = false,
          handler = false,
          sshfs = true,
        },
      },
    },
    keys = {
      { "<leader>rc", "<cmd>RemoteSSHFSConnect<cr>", desc = "Connect to remote host" },
      { "<leader>rd", "<cmd>RemoteSSHFSDisconnect<cr>", desc = "Disconnect from remote host" },
      { "<leader>re", "<cmd>RemoteSSHFSEdit<cr>", desc = "Edit ssh config" },
      { "<leader>rf", "<cmd>RemoteSSHFSFindFiles<cr>", desc = "Find files on remote" },
      { "<leader>rg", "<cmd>RemoteSSHFSLiveGrep<cr>", desc = "Live grep on remote" },
    },
  },
}