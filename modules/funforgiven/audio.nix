_: {
  dendritic.audio = {
    channels = [
      {
        id = "system";
        label = "System";
        sinkName = "funforgiven.audio.channel.system";
        bridgeName = "funforgiven.audio.channel.system.output";
        isDefault = true;
        initialGain = 1.0;
      }
      {
        id = "game";
        label = "Game";
        sinkName = "funforgiven.audio.channel.game";
        bridgeName = "funforgiven.audio.channel.game.output";
        isDefault = false;
        initialGain = 1.0;
      }
      {
        id = "voice";
        label = "Voice Chat";
        sinkName = "funforgiven.audio.channel.voice";
        bridgeName = "funforgiven.audio.channel.voice.output";
        isDefault = false;
        initialGain = 1.0;
      }
      {
        id = "music";
        label = "Music";
        sinkName = "funforgiven.audio.channel.music";
        bridgeName = "funforgiven.audio.channel.music.output";
        isDefault = false;
        initialGain = 1.0;
      }
    ];

    identityNormalizations = [ ];
  };
}
