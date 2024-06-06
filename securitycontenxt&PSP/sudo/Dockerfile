FROM        centos:7
RUN         yum install sudo -y
RUN         useradd demo
RUN         echo demo ALL= NOPASSWD: ALL >> /etc/sudoers
USER        demo

