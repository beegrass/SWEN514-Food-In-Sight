import './LandingPage.css';
import { FaCloudUploadAlt } from "react-icons/fa";
import {useState} from "react";
import {getPresignedUrl, imageUpload} from "../utils/ImageUploadUtil.ts";
import {image_data} from "../assets/image_data.tsx"
import { useNavigate } from 'react-router-dom';
import { ExpectedResultStructure } from '../utils/Types.tsx';
import { BeatLoader } from "react-spinners"; // Import spinner


const LandingPage= () => {

    const VITE_API_GATEWAY_URL = import.meta.env.VITE_API_GATEWAY_URL

    const [loading, setLoading] = useState(false);
    const [translateLoading, setTranslateLoading] = useState(false);

    const navigate = useNavigate()

    const [translateFile, setTranslateFile] = useState<File | null>(null);
    const [ImageUploadFile, setImageUploadFile] = useState<File | null>(null);

    async function sendFileKeyToTranslateEndpoint(fileKey: string) {
        try {
            const response = await fetch(`${VITE_API_GATEWAY_URL}/translate`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    "file_key": fileKey
                }),
            });

            if (!response.ok) {
                console.log("Failed to finish translation: ", response.statusText);
            }

            return await response.json();

        } catch (error) {
            console.error('Error sending fileKey:', error);
        }
    }

    async function triggerMainBackendFunction(fileKey: string) {
        try {
            const response = await fetch(`${VITE_API_GATEWAY_URL}/uploadimage`, { //technically 'uploadimage' isnt a good name anymore since presigned URLs
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({
                    "file_key": fileKey
                }),
            })

            if (!response.ok) {
                console.log("Failed to finish image analysis: ", response.statusText);
            }

            const data: ExpectedResultStructure = await response.json();
            navigate('/results', { state: { data: data } });

            return await response.json();

        } catch (error) {
            console.error('Error sending fileKey:', error);
        }
    }


    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!translateFile) {
            alert("Please upload a file first!");
            return;
        }
        setTranslateLoading(true);

        const endpoint = "/presign-translate";

        try {
            // First grab the pre-signed url used to upload to s3
            const preSignedUrl = await getPresignedUrl(endpoint, translateFile.name);

            console.log(`preSignedUrl: ${preSignedUrl}`);

            // then send the file using the Pre-signed URL
            const success = await imageUpload(translateFile, preSignedUrl);

            if(!success) {
                alert("Image upload failed, please try again")
            } else {
                const translatedText = await sendFileKeyToTranslateEndpoint(translateFile.name);
                setTranslateLoading(false);
                navigate('/translatedResults', { state: { translatedText: translatedText } });
            }

        } catch (error) {
            console.error("An error occurred during the file upload:", error);
        }
    };

    const Submit2 = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!ImageUploadFile) {
            alert("Please upload a file first!");
            return;
        }
        const endpoint = "/presign-main-upload";
        setLoading(true);
        const apiUrl = `${VITE_API_GATEWAY_URL}/uploadimage`;

        const preSignedUrl = await getPresignedUrl(endpoint, ImageUploadFile.name, ImageUploadFile.type);

        console.log(preSignedUrl)

        const success = await imageUpload(ImageUploadFile, preSignedUrl);

        console.log(success)

        if(!success) {
            alert("Image upload failed, please try again")
            return
        } else {
            const result = await triggerMainBackendFunction(`${success}${ImageUploadFile.name}`);
            setLoading(false);
            console.log(result)
        }

       
        setLoading(false)
    }

    return (
        <div className="landing-container">
            <h1>Upload an Image</h1>
            <main className="main-content">

                <form className="upload-section">
                    <h2>Upload Food Images</h2>
                    <input
                        onChange={(e) => 
                            {
                                setImageUploadFile(e.target.files?.[0] || null)
                            }}
                        type="file"
                        accept="image/*"
                    />
                    <button onClick={Submit2} className="upload-button" disabled={loading}>
                        {loading ? (
                            <BeatLoader size={10} color="#fff" />
                        ) : (
                            <>
                                Upload <FaCloudUploadAlt style={{ width: "10%" }} />
                            </>
                        )}
                    </button>
                </form>

                <form onSubmit={handleSubmit} className="translate-section">
                    <h2>Translate A Label</h2>
                    <input
                        onChange={(e) => setTranslateFile(e.target.files?.[0] || null)}
                        type="file"
                        accept="image/*" />
                    <button className="translate-label">{translateLoading ? (
                        <BeatLoader size={10} color="#fff" />
                    ) : (
                        <>
                            Translate Label <FaCloudUploadAlt style={{width:"10%"}} />
                        </>
                    )}</button>
                </form>
            </main>
        </div>
    );
};

export default LandingPage;