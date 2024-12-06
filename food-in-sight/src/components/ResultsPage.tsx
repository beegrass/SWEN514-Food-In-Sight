import './ResultsPage.css'
import { useLocation } from "react-router-dom";
import { ExpectedResultStructure } from '../utils/Types.tsx';

const ResultsPage = () => {

    const location = useLocation(); // Get location object which contains the state passed during navigation
    const data: ExpectedResultStructure = location.state?.data;
  
    return (
        <div className="main">
            <h1>Results Page</h1>
            <h2>Message:</h2>
            <p>{data.message}</p>
            <br/>
            <p>--------------------------------------</p>
            <h2>Diet Conflicts:</h2>
            <h3>Apple - apple-allergy</h3>
            <br/>
            <p>--------------------------------------</p>

            <h2>Raw Result:</h2>
            <p>{data.result}</p>

        </div>
    );
};

export default ResultsPage;