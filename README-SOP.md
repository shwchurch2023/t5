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
- Open: https://t5.shwchurch.org/wp-admin/upload.php?page=mla-menu&post_mime_type=audio&s=%E5%94%B1%E8%AF%97%E7%8F%AD&mla_search_connector=AND&mla_search_fields%5B0%5D=title&mla_search_fields%5B1%5D=excerpt&mla_search_fields%5B2%5D=content&mla_search_fields%5B3%5D=file&orderby=post_date&order=desc
- Execute JS `download-mp3-from-wp-admin-search.js`
    - If the page got old songs
        - Change the stopAt song name from last downloaded point, like `《241_奇异恩典》，来自 基督教北京守望教会唱诗班 的 新诗歌本。 发行于：2024。 音轨 241`
        - `downloadMp3s({ stopAt: "241_奇异恩典" });`
    - If the page is all new songs
        - `downloadMp3s()`

2. recreate playlist： https://t5.shwchurch.org/wp-admin/upload.php?page=mla-menu&s=%E5%9F%BA%E7%9D%A3%E6%95%99%E5%8C%97%E4%BA%AC%E5%AE%88%E6%9C%9B%E6%95%99%E4%BC%9A%E5%94%B1%E8%AF%97%E7%8F%AD&mla_search_connector=AND&mla_search_fields%5B0%5D=excerpt&mla_search_fields%5B1%5D=content&mla_filter_term=-1&order=desc&orderby=post_date&paged=3


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