## 背景

imaris 本体没有提供设置特定角度来统一视角的功能

如果不同文件都想要同一个视角，就很麻烦

简单了解了下imaris的插件开发（叫做XTensions）

迅速用matlab写了一个app，可以与imaris连接，设置特定角度，并可以快速复制视角和粘贴视角

> 备注：
>
> 写完之后，才发现其实imaris自带一个Camera Manager插件，也有复制位置、粘贴位置以及调制特定视角的功能（看来官方也知道这个问题，不明白为什么不加这个功能），但是这个插件有点难用：
>
> 要么安装matlab 特定版本的runtime（因为插件是用特定run time编译的，只能用特定run time运行，就算是同一个版本，比如matlab 2023a的9.14版本runtime，下载matlab官方最新的update8 runtime还有问题，必须用imaris之前打包插件的那个版本）。imaris下载runtime 贼慢，下载不下来，就放弃了。
>
> 要么使用imaris的Camera Manager的.m插件版本的，不用安装特定runtime，但是每次打开都会另打开一个matlab engine，太卡了，官方的Camera manager是把复制粘贴位置功能和调制特定视角功能做成两个按钮的，这意味着两个功能都用，就要打开两个matlab engine，不太能接受。
>
> 反正我后台平常也开着matlab，写成一个外部的app，后面如果要加其他功能，其实也更简单。

## 软件功能

Github：

![PixPin_2025-05-17_11-51-53](https://assets.b3logfile.com/siyuan/1610205759005/assets/PixPin_2025-05-17_11-51-53-20250517115156-mrxawb2.png)

- 连接imaris：选择imaris的安装文件夹，进行连接

  ![PixPin_2025-05-17_11-42-52](https://assets.b3logfile.com/siyuan/1610205759005/assets/PixPin_2025-05-17_11-42-52-20250517114254-ta68lfq.png)​
- 特定角度显示：设置X、Y、Z的旋转角度，来达到特定角度显示的效果

  ![PixPin_2025-05-17_11-43-36](https://assets.b3logfile.com/siyuan/1610205759005/assets/PixPin_2025-05-17_11-43-36-20250517114337-jho03e4.png)
- 复制和粘贴位置：快速让不同文件的显示视角一样

  复制位置

  ![PixPin_2025-05-17_11-45-56](https://assets.b3logfile.com/siyuan/1610205759005/assets/PixPin_2025-05-17_11-45-56-20250517114557-r1xr0wh.png)

  粘贴位置，让不同文件的显示视角一样

  ![PixPin_2025-05-17_11-46-17](https://assets.b3logfile.com/siyuan/1610205759005/assets/PixPin_2025-05-17_11-46-17-20250517114623-fndffzw.png)

## 如何安装

下载`Imaris Camera Manager.mlappinstall`​，在matlab打开安装即可，之后会在matlab顶栏显示

![PixPin_2025-05-17_11-55-37](https://assets.b3logfile.com/siyuan/1610205759005/assets/PixPin_2025-05-17_11-55-37-20250517115541-v099wls.png)

或者也可以直接运行，`ImarisCameraManager.mlapp`​或者`ImarisCameraManager_exported.m`​

## 开发笔记：开发一个imaris插件的三种方案

可以直接在imaris调用的matlab插件开发有两种方式，

一个是runtime版本，打包为exe，使用runtime来打开这个exe，缺点是必须安装打包这个exe时这个特定的runtime，否则运行不了

另一种是.m版本，相当于是直接使用当前安装的matlab来启动.m文件，缺点是，每次点开一个插件，就会打开一个matlab会话，使用起来很不方便

此外，还有一种方式，就是直接在当前的matlab软件内，连接imaris，对我而言，这种方式更舒服，后面要添加新功能，也自由，可以使用app designer来做app

## 开发笔记：外部matlab如何连接imaris

### 配置

首先先添加imaris的XT\matlab到路径

```matlab
addpath('C:\Program Files\Bitplane\Imaris x64 10.0.0\XT\matlab')
```

并添加ImarisLib.jar

```matlab
javaaddpath ImarisLib.jar; 
```

### 连接imaris的代码

```matlab
vImarisLib = ImarisLib;
vObjectId = 0; % this might be replaced by vObjectId = GetObjectId (see later)
vImarisApplication = vImarisLib.GetApplication(vObjectId);
viewer = vImarisApplication.GetSurpassCamera;
if isempty(viewer)
    error('No viewer found');
end

```

### 复制当前物体的位置

```matlab

quaternion = viewer.GetOrientationQuaternion;
position = viewer.GetPosition(); 
```

### 粘贴当前问题的位置

```matlab
viewer.SetOrientationQuaternion(quaternion);
viewer.SetPosition(position); 
```

### fit显示

```matlab
vImarisApplication.GetSurpassCamera.Fit;
```

### reset视角

```matlab
defaultQuaternion = [1, 0, 0, 0]; % Identity quaternion
viewer.SetOrientationQuaternion(quaternion);
vImarisApplication.GetSurpassCamera.Fit;
```

### 设置特定旋转角度

```matlab
yaw = deg2rad(-80);   % Rotation around Z-axis (in radians)：上下颠倒
pitch = deg2rad(0); % Rotation around X-axis (in radians)
roll = deg2rad(45);   % Rotation around Y-axis (in radians)：左右旋转

% Calculate quaternion from Euler angles (ZXY convention)
% Using manual quaternion calculation to avoid dependency on rotm2quat
% Quaternion: q = [w, x, y, z]
cy = cos(yaw/2);
sy = sin(yaw/2);
cp = cos(pitch/2);
sp = sin(pitch/2);
cr = cos(roll/2);
sr = sin(roll/2);

% ZXY rotation quaternion
w = cr*cp*cy + sr*sp*sy;
x = sr*cp*cy - cr*sp*sy;
y = cr*sp*cy + sr*cp*sy;
z = cr*cp*sy - sr*sp*cy;

% Ensure quaternion is normalized
quaternion = [w, x, y, z];
quaternion = quaternion / norm(quaternion);

% Apply rotation to the camera (1x4 vector)
viewer.SetOrientationQuaternion(quaternion);
vImarisApplication.GetSurpassCamera.Fit;
```
