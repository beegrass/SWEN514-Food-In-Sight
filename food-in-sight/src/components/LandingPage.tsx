import './LandingPage.css';
import { FaCloudUploadAlt } from "react-icons/fa";
import {useState} from "react";
import {getPresignedUrl, imageUpload} from "../utils/ImageUploadUtil.ts";
import {image_data} from "../assets/image_data.tsx"
import { useNavigate } from 'react-router-dom';
import { ExpectedResultStructure } from './Types.tsx';
import { BeatLoader } from "react-spinners"; // Import spinner


const LandingPage= () => {

    const VITE_API_GATEWAY_URL = import.meta.env.VITE_API_GATEWAY_URL

    const [loading, setLoading] = useState(false);

    const navigate = useNavigate()

    const [translateFile, setTranslateFile] = useState<File | null>(null);
    const [translateResult, setTranslateResult] = useState<any>("");

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


    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!translateFile) {
            alert("Please upload a file first!");
            return;
        }

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
                // Update the translateResult in the UI
                setTranslateResult(translatedText);
            }

        } catch (error) {
            console.error("An error occurred during the file upload:", error);
        }
    };

    const Submit2 = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        const apiUrl = `${VITE_API_GATEWAY_URL}/uploadimage`;

        try{

            const response = await fetch(apiUrl, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({
                    image_data: image_data,
                }),
            })
            const data: ExpectedResultStructure = await response.json();
            navigate('/results', { state: { data: data } });
            
        } catch (error) {
            console.error(`Error uploading image: ${error}`)
        } finally {
            setLoading(false)
        }
    }

    return (
        <div className="landing-container">
            <h1>Upload an Image</h1>
            <main className="main-content">

                <form className="upload-section">
                    <h2>Upload Food Images</h2>
                    <input
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
                    <button className="translate-label">Translate text in image <FaCloudUploadAlt style={{width:"10%"}} /></button>
                </form>

                {translateResult && (
                    <div>
                        <h3>Output:</h3>
                        {translateResult}
                    </div>
                )}

            </main>
        </div>
    );
};

export default LandingPage;