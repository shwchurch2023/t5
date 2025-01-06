const initWordpressHugoPlaylist = () => {
    // Define your playlist array
    // const playlist = [
    //     {
    //         name: "Song 1",
    //         artist: "Artist 1",
    //         src: "path/to/song1.mp3"
    //     },
    //     {
    //         name: "Song 2",
    //         artist: "Artist 2",
    //         src: "path/to/song2.mp3"
    //     },
    //     // Add more songs as needed
    // ];


    const currentPlayingClass = `wp-hugo-song-current-playing`;

    const getPlaylist = (containerSel = `.wp-audio-playlist`) => {
        const sel = `${containerSel} noscript`;
        const olString = document.querySelector(sel)?.innerText;

        if (!olString) {
            console.log(`[getPlaylist] Can't find text in selector [${sel}]`);
            return;
        }
        console.log(`getPlaylist`, `olString`, olString);

        const ol = new DOMParser().parseFromString(olString, `text/html`).querySelector(`ol`);

        console.log(`getPlaylist`, `ol`, ol);

        return Array.from(ol.querySelectorAll(`li a`)).map(a => {
            return {
                name: a.innerText,
                artist: `基督教北京守望教会唱诗班`,
                src: a.href,
            }
        })


    }

    const playlist = getPlaylist();

    if (!playlist || !playlist.length) {
        return;
    }

    const getExistingWordpressAudioElement = (container = `.wp-audio-playlist`) => {
        const sel = `${container} audio`;
        const audioEle = document.querySelector(sel);

        if (!audioEle) {
            console.error(`getAudioElement`, `audioEle`, `Can't find element with selector`, sel)
        }

        return audioEle;
    }

    const containerId = `wordpress_hugo_audio_playlist_player`;

    function prepareStyle() {
        const style = document.createElement('style');
        style.textContent = `
  #${containerId} {
    font-size: 14px;
  }
  #${containerId} .controls {
    margin-bottom: 20px;
  }
  #${containerId} .wp-hugo-song-current-playing {
    border-radius: 5px;
    background-color:#f7f7f7;
  }
#${containerId} button {
cursor: pointer;
}

`;
        document.head.appendChild(style);
    }


    function prepareAudioPlaylistHtml() {
        const htm = `

<div id="${containerId}">
    <div class="controls">
        <button id="prev">上一首</button>
        <button id="play">播放</button>
        <button id="next">下一首</button>
    </div>

    <div id="wp_hugo_playlist">
        <div class="song-info">
            <a class="song-title" href=""></a>
            
        </div>
    </div>
</div>
`;

        const wordpressAudioEle = getExistingWordpressAudioElement();

        const insertEle = document.createElement(`div`);

        insertEle.innerHTML = htm;

        wordpressAudioEle.after(insertEle);

        prepareStyle();

        return document.querySelector(`#${containerId}`);

    }

    const wordpressHugoAudioPlaylistPlayerElement = prepareAudioPlaylistHtml();

    // Get references to HTML elements
    const audio = getExistingWordpressAudioElement();

    const playBtn = wordpressHugoAudioPlaylistPlayerElement.querySelector("#play");
    const prevBtn = wordpressHugoAudioPlaylistPlayerElement.querySelector("#prev");
    const nextBtn = wordpressHugoAudioPlaylistPlayerElement.querySelector("#next");

    let currentSongIndex = +(localStorage.getItem(currentPlayingClass) || 0);

    audio.addEventListener("ended", (event) => {
        loadSong(currentSongIndex + 1)
    });

    // Function to load and play a song
    function loadSong(index) {
        const song = playlist[index];
        audio.src = song.src;

        audio.play();

        updatePlaylistWithCurrentPlaying(index);
    }

    updatePlaylist();

    function updatePlaylist() {
        const wp_hugo_playlist = document.querySelector(`#wp_hugo_playlist`);
        // wp_hugo_playlist.innerHTML = ``;

        wp_hugo_playlist.innerHTML = playlist.map(
            (song, idx) => {
                return `
        <div class="song-info" data-song-id="${idx}">
            <button class="song-title" data-song-id="${idx}">${song.name}</button>
            <a class="song-title" href="${song.src}" download>下载</a>
        </div>`
            }
        ).join(``);

        wp_hugo_playlist.addEventListener(`click`, (e) => {

            console.log(`updatePlaylist`, `click`, e?.target);

            const songId = e?.target?.getAttribute(`data-song-id`);

            if (!songId) {
                console.error(`updatePlaylist`, `addEventListener`, `The songId is null on [e?.target?.getAttribute("data - sone - id")]`);
                return;
            }
            loadSong(
                songId
            );

        })

    }


    function updatePlaylistWithCurrentPlaying(index) {


        const wp_hugo_playlist = document.querySelector(`#wp_hugo_playlist`);

        const allSongList = wp_hugo_playlist.querySelectorAll(".song-info");

        allSongList.forEach(
            songEle => songEle.classList.remove(currentPlayingClass)
        )

        const song = playlist[index];
        // const songArtist = wp_hugo_playlist.querySelectorAll(".song-artist")[index];

        playBtn.innerText = `播放(${song.name})`;

        allSongList[index].classList.add(currentPlayingClass);

        currentSongIndex = index;

        if (currentSongIndex === playlist.length - 1) {
            currentSongIndex = 0;
        }

        localStorage.setItem(currentPlayingClass, currentSongIndex);

        document.title = `${song.name} - ${document.querySelector(`h2.article-title`)?.innerText}`;


        // songArtist.textContent = song.artist;
    }

    // Play button event listener
    playBtn.addEventListener("click", () => {

        const song = playlist[currentSongIndex];

        if (audio.paused) {
            audio.play();
            // const songArtist = wp_hugo_playlist.querySelectorAll(".song-artist")[index];

            playBtn.textContent = `暂停(${song.name})`;
        } else {
            audio.pause();
            playBtn.textContent = `播放(${song.name})`;
        }
    });

    // Previous button event listener
    prevBtn.addEventListener("click", () => {
        currentSongIndex = (currentSongIndex - 1 + playlist.length) % playlist.length;
        loadSong(currentSongIndex);
    });

    // Next button event listener
    nextBtn.addEventListener("click", () => {
        currentSongIndex = (currentSongIndex + 1) % playlist.length;
        loadSong(currentSongIndex);
    });


    // Load the first song initially
    loadSong(currentSongIndex);
}

window.addEventListener(`load`, () => {
    initWordpressHugoPlaylist();
});