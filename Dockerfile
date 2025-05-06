###############################################################################
# ─────────────────────  STAGE 1 : build from source  ─────────────────────────
###############################################################################
FROM ros:iron-ros-base AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    COLCON_WS=/colcon_ws

# ---------- base build tools -------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential git cmake ninja-build pkg-config curl \
      python3-colcon-common-extensions python3-vcstool python3-rosdep \
      libudev-dev libusb-1.0-0-dev libyaml-cpp-dev libeigen3-dev \
      libboost-all-dev libopencv-dev libssl-dev

# ---------- rosdep init ------------------------------------------------------
RUN rm /etc/ros/rosdep/sources.list.d/20-default.list && \
    rosdep init && \
    rosdep update --include-eol-distros

# ---------- librealsense (user-space) ---------------------------------------
WORKDIR /tmp
RUN git clone --depth 1 https://github.com/IntelRealSense/librealsense.git && \
    cd  librealsense && mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release \
             -DFORCE_LIBUVC=ON -DBUILD_KERNEL=OFF \
             -DBUILD_WITH_SYSTEM_LIBUSB=ON \
             -DBUILD_EXAMPLES=OFF -DBUILD_GRAPHICAL_EXAMPLES=OFF && \
    cmake --build . -j$(nproc) && \
    cmake --install .

# ---------- create ROS 2 workspace ------------------------------------------
RUN mkdir -p ${COLCON_WS}/src
WORKDIR ${COLCON_WS}/src

RUN git clone -b ros2-development https://github.com/IntelRealSense/realsense-ros.git && \
    git clone -b ros2               https://github.com/SteveMacenski/slam_toolbox.git && \
    git clone -b rolling            https://github.com/CCNYRoboticsLab/imu_tools.git && \
    git clone -b ros2               https://github.com/cra-ros-pkg/robot_localization.git

# ---------- resolve ROS dependencies ----------------------------------------
WORKDIR ${COLCON_WS}
RUN apt-get update && \
    rosdep install --from-paths src --ignore-src -r -y --rosdistro iron && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ---------- build workspace --------------------------------------------------
RUN . /opt/ros/iron/setup.sh && \
    colcon build --merge-install --cmake-args -DCMAKE_BUILD_TYPE=Release

###############################################################################
# ────────────────  STAGE 2 : runtime (slim)  ────────────────────────────────
###############################################################################
FROM ros:iron-ros-base

ENV COLCON_WS=/colcon_ws \
    ROS_DISTRO=iron \
    LANG=C.UTF-8 \
    RMW_IMPLEMENTATION=rmw_fastrtps_cpp

# Minimal runtime libs for librealsense & OpenCV
RUN apt-get update && apt-get install -y --no-install-recommends \
      libusb-1.0-0 libudev1 libyaml-cpp0.7 libboost-system1.74.0 \
      libopencv-core4.5d libopencv-imgproc4.5d libopencv-imgcodecs4.5d && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy artefacts from builder
COPY --from=builder /usr/local /usr/local
COPY --from=builder /opt/ros/${ROS_DISTRO} /opt/ros/${ROS_DISTRO}
COPY --from=builder ${COLCON_WS}/install ${COLCON_WS}/install
COPY --from=builder /tmp/librealsense/config/99-realsense-libusb.rules /etc/udev/rules.d/

# Convenience: source workspaces for every shell
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /etc/bash.bashrc && \
    echo "source ${COLCON_WS}/install/setup.bash"   >> /etc/bash.bashrc

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["ros2", "launch", "realsense2_camera", "rs_launch.py", \
     "align_depth:=true", "enable_gyro:=true", "enable_accel:=true", \
     "unite_imu_method:=linear_interpolation"]
