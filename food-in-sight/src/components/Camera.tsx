import React, { useRef, useCallback } from 'react';
import Webcam from 'react-webcam';

const WebcamCapture: React.FC = () => {
  const webcamRef = useRef<Webcam>(null);

  const capture = useCallback(() => {
    if (webcamRef.current) {
      const imageSrc = webcamRef.current.getScreenshot();
      console.log(imageSrc);
      // You can handle the captured image here (e.g., upload to server, display in UI)
    } else {
      console.error("Webcam not accessible");
    }
  }, [webcamRef]);

  return (
    <div>
      <h2>Capture Image</h2>
      <Webcam
        audio={false}
        height={400}
        ref={webcamRef}
        screenshotFormat="image/jpeg"
        width={600}
        videoConstraints={{
          facingMode: "user"
        }}
      />
      <button onClick={capture}>Capture Photo</button>
    </div>
  );
};

export default WebcamCapture;