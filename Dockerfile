# SLAM with ROS

FROM ros:kinetic-ros-core

# install ROS
# https://docs.ros.org/en/kinetic/Installation/Ubuntu-Install-Debians.html

RUN apt-get update && apt-get install -y \
    software-properties-common \
    curl \
    && add-apt-repository universe


# Add the ROS 2 apt repository to your system
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/ros2-latest.list > /dev/null && \
    apt-get update -y && apt-get upgrade -y && apt-get install -y \
    ros-kinetic-ros-base \
    ros-kinetic-rtabmap-ros \
    ros-kinetic-robot-localization \
    ros-kinetic-imu-filter-madgwick \
    ros-kinetic-realsense2-*

# Install rviz
RUN apt-get install -y ros-kinetic-rviz

# install x11 so it can interact with the host
RUN apt-get install -y x11-apps

# install git
RUN apt-get install -y git

# Download the https://github.com/IntelRealSense/realsense-ros
RUN curl -L0 https://github.com/IntelRealSense/librealsense/archive/refs/tags/v2.18.1.zip -o v2.18.1.zip

# unzip the file
RUN apt install -y unzip
RUN unzip v2.18.1.zip

# install python
RUN apt-get install -y python3-pip nano

RUN rosdep init
