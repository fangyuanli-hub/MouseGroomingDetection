% 1. 交互式选择包含 MP4 文件的文件夹
folder_path = uigetdir('N:\SUN-IN-Lind-lab\Fangyuan\Data\11_Data_AstCalCTRL', '请选择包含 MP4 视频的文件夹');
if folder_path == 0
    disp('未选择文件夹，程序退出。');
    return;
end

% 获取文件夹中所有的 .mp4 文件
video_files = dir(fullfile(folder_path, '*.mp4'));
if isempty(video_files)
    disp('所选文件夹中没有找到 MP4 文件。');
    return;
end

% 2. 读取第一个视频的第一帧，供用户交互式选择ROI(感兴趣区域)
first_video_path = fullfile(video_files(1).folder, video_files(1).name);
v_init = VideoReader(first_video_path);
first_frame = readFrame(v_init);

% 弹出图像窗口让用户裁剪
figure('Name', '请在图像上框选要检测的区域，然后双击确认');
imshow(first_frame);
title('请用鼠标框选区域，完成后【双击选框内部】确认');

% imcrop 返回裁剪后的图像和位置向量 [xmin, ymin, width, height]
[~, roi_rect] = imcrop(first_frame);
close(gcf); % 关闭图像窗口

if isempty(roi_rect)
    disp('未选择区域，程序退出。');
    return;
end

fprintf('已选定检测区域: x=%.1f, y=%.1f, 宽=%.1f, 高=%.1f\n', ...
    roi_rect(1), roi_rect(2), roi_rect(3), roi_rect(4));

% --- 参数设置区 ---
% 视频由于压缩和光照可能会有噪点，因此需要设置变化阈值
pixel_diff_threshold = 30;     % 单个像素灰度值的变化差值阈值 (0-255)
area_change_threshold = 0.05;  % 发生变化的像素占区域总像素的比例 (例如 0.05 表示 5% 的面积发生变化)

changed_videos = {};

% 3. 遍历所有视频并检测所选区域内的变化
disp('------------------------------');
disp('开始逐个检测视频...');

for i = 1:length(video_files)
    video_name = video_files(i).name;
    video_path = fullfile(video_files(i).folder, video_name);
    
    v = VideoReader(video_path);
    has_change = false;
    
    % 读取该视频的第一帧作为参考帧
    if hasFrame(v)
        prev_frame = readFrame(v);
        % 转换为灰度图，加速计算并减少色彩噪点干扰
        if size(prev_frame, 3) == 3
            prev_frame = rgb2gray(prev_frame);
        end
        % 截取指定区域
        prev_roi = imcrop(prev_frame, roi_rect);
    else
        continue;
    end
    
    % 逐帧比较 (相邻帧差法)
    while hasFrame(v)
        curr_frame = readFrame(v);
        
        if size(curr_frame, 3) == 3
            curr_frame = rgb2gray(curr_frame);
        end
        curr_roi = imcrop(curr_frame, roi_rect);
        
        % 计算绝对差值
        diff_roi = abs(double(curr_roi) - double(prev_roi));
        
        % 统计超过差值阈值的像素个数
        changed_pixels = sum(diff_roi(:) > pixel_diff_threshold);
        total_pixels = numel(diff_roi);
        
        % 判断变化面积是否超过比例阈值
        if (changed_pixels / total_pixels) > area_change_threshold
            has_change = true;
            break; % 检测到变化，无需继续读取该视频的后续帧，直接跳出当前 while 循环
        end
        
        % 更新参考帧为当前帧 (如果想比较第一帧和当前帧，请注释掉下面这行)
        prev_roi = curr_roi; 
    end
    
    % 4. 报告结果
    if has_change
        fprintf('🔴 检测到变化: %s\n', video_name);
        changed_videos{end+1} = video_name; %#ok<AGROW>
    else
        fprintf('⚪ 无明显变化: %s\n', video_name);
    end
end

% 总结报告
disp('------------------------------');
disp('检测完成！');
if isempty(changed_videos)
    disp('所有视频在指定区域内均未检测到明显变化。');
else
    fprintf('共发现 %d 个视频发生变化。\n', length(changed_videos));
end