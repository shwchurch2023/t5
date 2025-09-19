# SOPs

## Create new media distribution account
- Create new outlook email account, e.g. `shwchurch2030media@outlook.com`
- Create new Github account with the new outlook email account, e.g. Github username: `shwchurch2030media`
- Create new repo for GitHub pages, e.g. `shwchurch2030media.github.io`
- Add new Github rules to protect the branch `main` (even it doesn't exit) 
- Generate new SSH Key in /mnt/hugo/ssh with name pattern `id_ed25519_shwchurch2030media` (changed the year to the new account)
- Search this repo with keyword `uploadsGitUsername3`; copy all the matches and rename with new suffix, e.g. `uploadsGitUsername4` and add the new `shwchurch2030media` git account to it
- Perform a new `./deploy.sh`


## Update Shouwang Choir playlist
### Update source

1. Get all new hymns： 
- 过滤所有没有标签的Choir MP3: https://t5.shwchurch.org/wp-admin/upload.php?s=%E5%9F%BA%E7%9D%A3%E6%95%99%E5%8C%97%E4%BA%AC%E5%AE%88%E6%9C%9B%E6%95%99%E4%BC%9A%E5%94%B1%E8%AF%97%E7%8F%AD&mla_search_fields%5B0%5D=title&mla_search_fields%5B1%5D=excerpt&mla_search_fields%5B2%5D=content&mla_search_fields%5B3%5D=file&mla_search_connector=AND&mla_debug_data=none%2Cmla-thumbnail-generation-scripts+action+click+n+%3D+action%2C+action+%3D+edit%2Cmla-inline-edit-scripts+action+click+n+%3D+action%2C+action+%3D+edit&page=mla-menu&post_mime_type=audio&order=desc&orderby=post_date&_wpnonce=b71336380d&_wp_http_referer=%2Fwp-admin%2Fupload.php%3Fpage%3Dmla-menu&action=-1&m=0&mla_filter_term=-1&mla_filter=Filter&paged=1&cb_attachment%5B0%5D=24190&cb_attachment%5B1%5D=24189&cb_attachment%5B2%5D=24114&cb_attachment%5B3%5D=24113&cb_attachment%5B4%5D=24089&cb_attachment%5B5%5D=23998&cb_attachment%5B6%5D=23975&cb_attachment%5B7%5D=23974&cb_attachment%5B8%5D=23945&cb_attachment%5B9%5D=23887&cb_attachment%5B10%5D=23830&cb_attachment%5B11%5D=23802&cb_attachment%5B12%5D=23768&cb_attachment%5B13%5D=23455&cb_attachment%5B14%5D=23392&cb_attachment%5B15%5D=23382&cb_attachment%5B16%5D=23368&cb_attachment%5B17%5D=23367&cb_attachment%5B18%5D=23339&cb_attachment%5B19%5D=23325&action2=-1 
- 添加标签
    - 批量操作
    - 选择标签 `基督教北京守望教会唱诗班诗歌合辑`
    - Update
    - 下一页；然后重复上面
- Optional： 下载 Execute JS `download-mp3-from-wp-admin-search.js`
    - If the page got old songs
        - Change the stopAt song name from last downloaded point, like `《241_奇异恩典》，来自 基督教北京守望教会唱诗班 的 新诗歌本。 发行于：2024。 音轨 241`
        - `downloadMp3s({ stopAt: "241_奇异恩典" });`
    - If the page is all new songs
        - `downloadMp3s()`

2. 更新 playlist： 
- https://t5.shwchurch.org/wp-admin/post.php?post=24180&action=edit
- 编辑播放列表
- “添加进音频播放列表”
- 搜索标签： 基督教北京守望教会唱诗班诗歌合辑
- 加载更多（前N个-只显示还没有在列表里的，可能是0）
```javascript
Array.from(document.querySelectorAll(`.attachment.save-ready`)).forEach(li => li.click())
```
- 点击“添加进音频播放列表”
- 点击 “更新播放列表”
- 点击“保存”
- 刷新： https://t5.shwchurch.org/#/hashEventClick/selector/ID_main_choir
- 等待 Github 更新


### Update Youtube
- Execute the Javascript in `./bin/download-sw-choir.sh` according to its hints;

- Download mp3
```zsh
    ./bin/download-sw-choir.sh
```
- Convert to mp4
```zsh
    ./bin/convert-sw-choir.sh

```

- Upload all converted mp4 videos (not mp3) to https://studio.youtube.com/playlist/PLEG4fp4NcO60_cE5DYNf8vpJ0U_WuOtTT/videos 