#!/bin/bash

# Chathan Desktop
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDm7GNnNd2Rwls+wdubm1HQmIH9o3nxMZhofRTIbaq9rgjc+JCQPxOoQKfrfju6uJhQTMD66CASawafSUGpc4sKewNESe03UYdc4GuJglw9pQhF26zBLYm+1fhXx1Q94Bp0K6CmVXqp7xoC809h1nDjJt6YJULGK9BBUVxiQ7DMJwrJe5sukX5WZIF0kkG030Jcu6Ma9zMOY47Y9Jmkhmsg71bPAU0Pp80i4PNNjYL0/a6Bqz9zFT24IrNiP5MLFFaJTzZYQ9GoYfbAmhG3ZsvXpBjzkreHW+gfqQgIaOUvEMw2sd8kFbq87e/8AQpKgOlQV0U3I683eCZy3ZmI5uQFmXhB/heg0l3yxtWm3nIbnToNWy2bdSuvqa6nN5bsUfGYuoQke8R/tw6vzR8qnfRq/mpVGrky7+9lYrwgK4+jXie7fnm1Yuv8eSVsLukcQ0+CmVpkRFP1a8QQShiUlgE8u8KifHssr4fn33huS7nEZkl8UIgE7Z3K1Mrytw9RAxB+HLcs/beV5AdDRz5K/HlGJnlVCL/0LaZ13SCn+Rc3ZjqTA/JyWVBWkp9q/GLT6XmF6EL2NsgykZcIetV5wgLs1Un9/cMSohQ1Xd2pNU1OxMdVqJP7qx0sU/SagBt0jVOjJnGfY4aWZZl9X/9bskP495vFUSKRoSTRFLUmnG/hbQ== chathan@driehuys.com" > /home/ubuntu/.ssh/authorized_keys

chown ubuntu: /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/authorized_keys